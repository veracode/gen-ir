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

	/// Mapping of dynamic dependencies (inside the xcarchive) to their paths on disk
	private let dynamicDependencyToPath: [String: URL]

	private let graph: DependencyGraph

	init(archive: URL, output: URL, targets: Targets) throws {
		self.output = output

		dynamicDependencyToPath = dynamicDependencies(in: self.archive)

		graph = DependencyGraphBuilder.build(targets: targets)
	}

	/// Starts the OutputPostprocessor
	/// - Parameter targets: the targets to operate on
	func  process(targets: inout Targets) throws {
		try FileManager.default.directories(at: output, recursive: false)
			.forEach { path in
				let product = path.lastPathComponent.deletingPathExtension()

				guard let target = targets.target(for: product) else {
					logger.error("Failed to look up target for product: \(product)")
					return
				}

				target.irFolderPath = path
			}

		// TODO: remove 'static' deps so we don't duplicate them in the submission?
		_ = try FileManager.default.directories(at: output, recursive: false)
			.flatMap { path in
				let product = path.lastPathComponent.deletingPathExtension()

				guard let target = targets.target(for: product) else {
					logger.error("Failed to look up target for product: \(product)")
					return Set<URL>()
				}

				return try process(target: target)
			}
	}

	/// Processes an individual target
	/// - Parameters:
	///   - target: the target to process
	///   - path: the output path
	/// - Returns:
	private func process(
		target: Target
	) throws -> Set<URL> {
		let chain = graph.chain(for: target)

		logger.info("Chain for target: \(target.nameForOutput):\n")
		chain.forEach { logger.info("\($0)") }

		// We want to process the chain, visiting each node _shallowly_ and copy it's dependencies into it's parent
		var processed = Set<URL>()

		for node in chain {
			logger.debug("Processing Node: \(node.name)")
			// Ensure node is not a dynamic dependency
			guard dynamicDependencyToPath[node.target.nameForOutput] == nil else { continue }

			// Only care about moving dependencies into dependers - check this node's edges to dependent relationships
			let dependers = node.edges
				.filter { $0.relationship == .depender }
				.map { $0.to }

			// Move node's IR into depender's IR folder
			guard let nodeFolderPath = node.target.irFolderPath else {
				logger.debug("IR folder for node: \(node) is nil")
				continue
			}

			for depender in dependers {
				guard let dependerFolderPath = depender.target.irFolderPath else {
					logger.debug("IR folder for depender node \(depender) is nil")
					continue
				}

				// Move the dependency IR (the node) to the depender (the thing depending on this node)
				do {
					try FileManager.default.copyItemMerging(at: nodeFolderPath, to: dependerFolderPath, replacing: true)
				} catch {
					logger.debug("Copy error: \(error)")
				}
				processed.insert(nodeFolderPath)
			}
		}

		return processed
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
