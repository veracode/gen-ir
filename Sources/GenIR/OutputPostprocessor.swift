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
struct OutputPostprocessor {
	/// The to the output IR folders that will be processed
	let output: URL

	/// The archive path, this should be the parent path of `output`
	let archive: URL

	/// Mapping of dynamic dependencies (inside the xcarchive) to their paths on disk
	private let dynamicDependencyToPath: [String: URL]

	init(archive: URL, output: URL) throws {
		self.output = output
		self.archive = archive

		dynamicDependencyToPath = dynamicDependencies(in: archive)
	}

	/// Starts the OutputPostprocessor
	/// - Parameter targets: the targets to operate on
	func  process(targets: inout Targets) throws {
		let targetsToPaths = try FileManager.default.directories(at: output, recursive: false)
			.reduce(into: [Target: URL]()) { partialResult, path in
				let product = path.lastPathComponent.deletingPathExtension()

				guard let target = targets.target(for: product) else {
					logger.error("Failed to look up target for product: \(product)")
					return
				}

				partialResult[target] = path
			}

		// TODO: remove 'static' deps so we don't duplicate them in the submission?
		let _ = try targets.flatMap { target in
			guard let path = targetsToPaths[target] else {
				logger.error("Couldn't find path for target: \(target)")
				return Set<URL>()
			}

			return try process(target: target, in: targets, at: path, with: targetsToPaths)
		}
	}

	/// Processes an individual target
	/// - Parameters:
	///   - target: the target to process
	///   - targets: a list of all targets
	///   - path: the output path
	///   - targetsToPaths: a map of targets to their IR folder paths
	/// - Returns:
	private func process(
		target: Target,
		in targets: Targets,
		at path: URL,
		with targetsToPaths: [Target: URL]
	) throws -> Set<URL> {
		let dependencies = targets.calculateDependencies(for: target)

		let staticDependencies = dependencies
			.filter { dynamicDependencyToPath[$0] == nil }

		let processedPaths = try staticDependencies
			.compactMap { product -> URL? in
				guard let dependencyTarget = targets.target(for: product) else {
					logger.debug("Failed to lookup target for product: \(product)")
					return nil
				}

				guard let dependencyPath = targetsToPaths[dependencyTarget] else {
					logger.debug("Failed to lookup path for target: \(dependencyTarget.name)")
					return nil
				}

				try FileManager.default.copyItemMerging(at: dependencyPath, to: path)
				return dependencyPath
			}

		return Set(processedPaths)
	}
}

// swiftlint:disable private_over_fileprivate
/// Returns a map of dynamic objects in the provided path
/// - Parameter xcarchive: the path to search through
/// - Returns: a mapping of filename to filepath for dynamic objects in the provided path
fileprivate func dynamicDependencies(in xcarchive: URL) -> [String: URL] {
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

/// Returns the base URL to start searching inside an xcarchive
/// - Parameter path: the original path, should be an xcarchive
/// - Returns: the path to start a dependency search from
fileprivate func baseSearchPath(startingAt path: URL) -> URL {
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
// swiftlint:enable private_over_fileprivate
