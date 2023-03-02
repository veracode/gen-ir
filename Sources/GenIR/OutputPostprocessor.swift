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
	private let dynamicFrameworksToPaths: [String: URL]
	/// Mapping of products (inside the IR folder) to their paths on disk
	private let productsToPaths: [String: URL]

	init(targets: [String: Target], xcarchive: URL, output: URL) throws {
		self.targets = targets
		self.output = output

		dynamicFrameworksToPaths = try FileManager.default.filteredContents(of: xcarchive.appendingPathComponent("Products")) { path in
			let attributes = try path.resourceValues(forKeys: [.isDirectoryKey])
			return attributes.isDirectory ?? false && path.lastPathComponent == "Frameworks"
		}
		.flatMap {
			try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)
				.filter { $0.lastPathComponent.hasSuffix(".framework") }
		}
		.reduce(into: [String: URL](), { partialResult, url in
			let name = url.deletingPathExtension().lastPathComponent
			partialResult[name] = url
		})

		// Build a map of product names to the target names they represent.
		// Here we have the product name via the on-disk representation
		let productsToTargets = targets.reduce(into: [String: String](), { partialResult, item in
			partialResult[item.1.product] = item.1.name
		})

		// TODO: need to look up product names to get the target names :/
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
			.filter { dynamicFrameworksToPaths[$0] == nil } // if this dependency is dynamic, we can ignore it - we want IR as a separate item
			.compactMap { name in
				// Copy the contents to the target directory
				if let dependencyPath = productsToPaths[name] {
					try FileManager.default.copyItemMerging(at: dependencyPath, to: path, replacing: true)
					return dependencyPath
				}

				logger.error("Failed to get path for depenedency: \(name)")
				return nil
			}
	}
}
