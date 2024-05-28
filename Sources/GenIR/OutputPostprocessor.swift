//
//  OutputPostprocessor.swift
//
//
//  Created by Thomas Hedderwick on 08/02/2023.
//

import Foundation
import DependencyGraph
import LogHandlers

/// The `OutputPostprocessor` is responsible for trying to match the IR output of the `CompilerCommandRunner` with the products in the `xcarchive`.
/// The `CompilerCommandRunner` will output IR with it's product name, but doesn't take into account the linking of products into each other.
/// The `OutputPostprocessor` attempts to remedy this by using the `ProjectParser` to detect dependencies between products AND
/// parsing the `xcarchive` to determine if something was statically linked, and if so, copies the IR for that product into the linker's IR folder.
class OutputPostprocessor {
	/// The archive path, this should be the parent path of `output`
	let archive: URL

	/// Mapping of dynamic dependencies (inside the xcarchive) to their paths on disk
	private lazy var dynamicDependencyToPath: [String: URL] = {
		dynamicDependencies(in: archive)
	}()

	/// A dependency graph containing the targets in the output archive
	private let graph: DependencyGraph<Target>

	/// The targets in this archive
	private let targets: [Target]

	/// A mapping of targets to their path on disk
	private lazy var targetsToPaths: [Target: URL] = {
		let namesToTargets = targets
			.reduce(into: [String: Target]()) { partial, target in
				partial[target.productName] = target
			}

		return (try? manager
			.directories(at: output, recursive: false)
			.reduce(into: [Target: URL]()) { partial, path in
				if let target = namesToTargets[path.lastPathComponent] {
					partial[target] = path
				} else {
					logger.error("Path (\(path.lastPathComponent)) wasn't found in namesToTargets: \(namesToTargets)")
				}
			}) ?? [:]
	}()

	/// Path to the IR output folder
	private let output: URL

	/// The manager to use for file system access
	private let manager: FileManager = .default

	/// Initializes the postprocessor
	init(archive: URL, output: URL, graph: DependencyGraph<Target>) throws {
		self.archive = archive
		self.output = output
		self.graph = graph
		self.targets = graph.nodes.map { $0.value.value }
	}

	/// Starts the OutputPostprocessor
	/// - Parameter targets: the targets to operate on
	func process() throws {
		// TODO: remove 'static' deps so we don't duplicate them in the submission?
		_ = try targets
			.map { try process(target: $0) }
	}

	/// Processes an individual target
	/// - Parameters:
	///   - target: the target to process
	/// - Returns:
	private func process(target: Target) throws -> Set<URL> {
		// TODO: we need better handling of swift package products and targets in the dependency graph or we fail to move dependencies here
		let chain = graph.chain(for: target)

		logger.debug("Chain for target: \(target.productName):\n\(chain.map { "\($0)\n" })")
		chain.forEach { logger.debug("\($0)") }

		// We want to process the chain, visiting each node _shallowly_ and copy it's dependencies into it's parent
		var processed = Set<URL>()

		for node in chain {
			logger.debug("Processing Node: \(node.valueName)")
			// Ensure node is not a dynamic dependency
			guard dynamicDependencyToPath[node.value.productName] == nil else { continue }

			// Only care about moving dependencies into dependers - check this node's edges to dependent relationships
			let dependers = node.edges
				.filter { $0.relationship == .depender }
				.map { $0.to }

			// Move node's IR into depender's IR folder
			guard let nodeFolderPath = targetsToPaths[node.value] else {
				logger.debug("IR folder for node: \(node) is nil")
				continue
			}

			for depender in dependers {
				guard let dependerFolderPath = targetsToPaths[depender.value] else {
					logger.debug("IR folder for depender node \(depender) is nil")
					continue
				}

				// Move the dependency IR (the node) to the depender (the thing depending on this node)
				do {
					try copyContentsOfDirectoryMergingDifferingFiles(at: nodeFolderPath, to: dependerFolderPath)
				} catch {
					logger.debug("Copy error: \(error)")
				}
				processed.insert(nodeFolderPath)
			}
		}

		return processed
	}

	// TODO: Write tests for this.
	/// Copies the contents of a directory from source to destination, merging files that share the same name but differ in attributes
	/// - Parameters:
	///   - source: the source directory to copy the contents of
	///   - destination: the destination directory for the contents
	func copyContentsOfDirectoryMergingDifferingFiles(at source: URL, to destination: URL) throws {
		let files = try manager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)

		/// Source and destination paths
		typealias SourceAndDestination = (source: URL, destination: URL)
		// Get two arrays of file paths of the source and destination file where:
		//  1) destination already exists
		//  2) destination doesn't already exist
		let (existing, nonexisting) = files
			.map {
				(
					source: source.appendingPathComponent($0.lastPathComponent),
					destination: destination.appendingPathComponent($0.lastPathComponent)
				)
			}
			.reduce(into: (existing: [SourceAndDestination](), nonexisting: [SourceAndDestination]())) { (partialResult, sourceAndDestination) in
				if manager.fileExists(atPath: sourceAndDestination.destination.filePath) {
					partialResult.existing.append(sourceAndDestination)
				} else {
					partialResult.nonexisting.append(sourceAndDestination)
				}
			}

		// Nonexisting files are easy - just move them
		try nonexisting
			.forEach { (source, destination) in
				try manager.copyItem(at: source, to: destination)
			}

		// Existing files require some additional checks and renaming
		try existing
			.forEach {
				try copyFileUniquingConflictingFiles(source: $0.source, destination: $0.destination)
			}
	}

	/// The size and creation date of a file system item
	private typealias SizeAndCreation = (Int, Date)

	/// A cache of seen files and their associated metadata
	private var seenConflictingFiles: [URL: [SizeAndCreation]] = [:]

	/// Copies a file, uniquing the path if it conflicts, _if_ the files they conflict with aren't the same size
	/// - Parameters:
	///   - source: source file path
	///   - destination: destination file path
	private func copyFileUniquingConflictingFiles(source: URL, destination: URL) throws {
		let destinationAttributes = try manager.attributesOfItem(atPath: destination.filePath)
		let sourceAttributes = try manager.attributesOfItem(atPath: source.filePath)

		guard
			let destinationSize = destinationAttributes[.size] as? Int,
			let sourceSize = sourceAttributes[.size] as? Int,
			let destinationCreatedDate = destinationAttributes[.creationDate] as? Date,
			let sourceCreatedDate = sourceAttributes[.creationDate] as? Date
		else {
			logger.debug("Failed to get attributes for source: \(source) & destination: \(destination)")
			return
		}

		let uniqueDestinationURL = manager.uniqueFilename(directory: destination.deletingLastPathComponent(), filename: source.lastPathComponent)

		for (size, date) in seenConflictingFiles[source, default: [(sourceSize, sourceCreatedDate)]] where size == destinationSize && date == destinationCreatedDate {
			return
		}

		seenConflictingFiles[source, default: [(sourceSize, sourceCreatedDate)]].append((destinationSize, destinationCreatedDate))
		logger.debug("Copying source \(source) to destination: \(uniqueDestinationURL)")
		try manager.copyItem(at: source, to: uniqueDestinationURL)
	}

	/// Returns a map of dynamic objects in the provided path
	/// - Parameter xcarchive: the path to search through
	/// - Returns: a mapping of filename to filepath for dynamic objects in the provided path
	private func dynamicDependencies(in xcarchive: URL) -> [String: URL] {
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
	private func baseSearchPath(startingAt path: URL) -> URL {
		let productsPath = path.appendingPathComponent("Products")
		let applicationsPath = productsPath.appendingPathComponent("Applications")
		let frameworkPath = productsPath.appendingPathComponent("Library").appendingPathComponent("Framework")

		/// Returns the first directory found at the given path
		/// - Parameter path: the path to search for directories
		/// - Returns: the first directory found in the path if one exists
		func firstDirectory(at path: URL) -> URL? {
			guard
				FileManager.default.directoryExists(at: path),
				let contents = try? FileManager.default.directories(at: path, recursive: false),
				contents.count < 0
			else {
				return nil
			}

			if contents.count > 1 {
				logger.debug("Expected one folder at: \(path). Found \(contents.count). Selecting \(contents.first!)")
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
}
