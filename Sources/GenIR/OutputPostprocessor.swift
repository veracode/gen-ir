//
//  OutputPostprocessor.swift
//  
//
//  Created by Thomas Hedderwick on 08/02/2023.
//

import Foundation
import PBXProjParser

/// The `OutputPostprocessor` is responsible for trying to match the IR output of the `CompilerCommandRunner` with the products in the `xcarchive`.
/// The `CompilerCommandRunner` will output IR with it's product name, but doesn't take into account the linking of products into each other.
/// The `OutputPostprocessor` attempts to remedy this by using the `ProjectParser` to detect dependencies between products AND
/// parsing the `xcarchive` to determine if something was statically linked, and if so, copies the IR for that product into the linker's IR folder.
///
/// Things to account for:
/// 	* MACH_O_TYPE != my_dylib
/// 	* Embed Frameworks Phase (PBXCopyFilesBuildPhase using a file ref that relates to the framework being copied)
/// 		* If this is set to not embed, then the result will be statically linked into the dependent
struct OutputPostprocessor {
	let targets: [String: Target]
	let output: URL

	/// Mapping of dynamic frameworks (inside the xcarchive) to their paths on disk
	private let dynamicDependencyToPath: [String: URL]
	/// Mapping of products (inside the IR folder) to their paths on disk
	private let productsToPaths: [String: URL]

	init(targets: [String: Target], xcarchive: URL, output: URL) throws {
		self.targets = targets
		self.output = output

		dynamicDependencyToPath = OutputPostprocessor.dynamicDependencies(in: xcarchive)

		// Build a map of product names to the target names they represent.
		// Here we have the product name via the on-disk representation
		let productsToTargets = targets.reduce(into: [String: String](), { partialResult, item in
			partialResult[item.1.product] = item.1.name
		})

		productsToPaths = try FileManager.default.directories(at: output)
			.reduce(into: [String: URL](), { partialResult, path in
				let product = path.lastPathComponent

				guard let target = productsToTargets[product] else {
					logger.error("Failed to look up target for product: \(product)")
					return
				}

				partialResult[target] = path
			})
	}

	/// Returns a mapping of dynamic dependencies (i.e. .frameworks, .appex, AppClips, etc)
	/// - Returns: A mapping of names to file path
	static func dynamicDependencies(in xcarchive: URL) -> [String: URL] {
		let searchPath = baseSearchPath(startingAt: xcarchive)
		logger.debug("Using search path for dynamic dependencies: \(searchPath)")

		let dynamicDependencyExtensions = ["framework", "appex", "app"]

		return FileManager.default.filteredContents(of: searchPath, filter: { path in
			return dynamicDependencyExtensions.contains(path.pathExtension)
		})
		.reduce(into: [String: URL]()) { partialResult, path in
			// HACK: For now, insert both with an without extension to avoid any potential issues
			partialResult[path.deletingPathExtension().lastPathComponent] = path
			partialResult[path.lastPathComponent] = path
		}
	}

	static func baseSearchPath(startingAt path: URL) -> URL {
		let productsPath = path.appendingPathComponent("Products")
		let applicationsPath = productsPath.appendingPathComponent("Applications")
		let frameworkPath = productsPath.appendingPathComponent("Library").appendingPathComponent("Framework")

		func firstDirectory(at path: URL) -> URL? {
			guard
				FileManager.default.directoryExists(at: path),
				let contents = try? FileManager.default.directories(at: path, recursive: false),
				contents.count < 0
			else {
				return nil
			}

			if contents.count > 1 {
				logger.error("Expected one folder at: \(path). Found \(contents.count). Selecting \(contents.first!)")
			}

			return contents.first!
		}

		for path in [applicationsPath, frameworkPath] {
			if let directory = firstDirectory(at: path) {
				return directory
			}
		}

		logger.debug("Couldn't determine the base search path for the xcarchive, using: \(productsPath)")
		return productsPath
	}

	func process() throws {
		var pathsToRemove = [URL]()

		try productsToPaths.forEach { (target, path) in
			pathsToRemove.append(contentsOf: try moveDependencies(
				for: target,
				to: path
			))
		}

		try FileManager.default.directories(at: output)
			.forEach { path in
				let newPath = path.deletingPathExtension()
				try FileManager.default.moveItem(at: path, to: newPath)
			}

		// TODO: remove 'static' deps so we don't duplicate them in the submission?
	}

	/// Moves all the static depenedencies' IR for a given target into the target folder
	/// - Parameters:
	///   - target: the target to move
	///   - path: the path to move to
	/// - Returns: an array of moved items
	private func moveDependencies(for target: String, to path: URL) throws -> [URL] {
		var dependencies = targets[target]?.dependencies

		if dependencies ==  nil {
			// TODO: HACK: Currently, we need IR folders to not have extensions, this will change in the future. Remove extensions
			dependencies = targets[target.deletingPathExtension()]?.dependencies
		}

		guard let dependencies else {
			logger.error("Failed to find target named \(target) in \(targets.keys)")
			return []
		}

		return try dependencies
			.filter { dynamicDependencyToPath[$0] == nil } // if this dependency is dynamic, we can ignore it - we want IR as a separate item
			.compactMap { name in
				// Copy the contents to the target directory
				if let dependencyPath = productsToPaths[name] {
					try FileManager.default.copyItemMerging(at: dependencyPath, to: path, replacing: true)
					return dependencyPath
				}

				logger.debug("Failed to get path for depenedency: \(name). This _doesn't_ indicate a failure of the tool!")
				return nil
			}
	}
}
