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

	/// Path to the folder containing build artifacts
	private let build: URL

	/// The manager to use for file system access
	private let manager: FileManager = .default

	/// Cache of all files that have been copied to the IR output folder.
	/// This maps a destination to a set of source URLs. This is used to determine if a file has already
	/// been copied without having to waste cycles comparing file contents. If multiple source files
	/// map to the same destination, then they will be given unique file names when copied to the IR folder.
	private var copiedFiles: [URL: Set<URL>] = [:]

	/// Initializes the postprocessor
	init(archive: URL, build: URL, graph: DependencyGraph<Target>) throws {
		self.archive = archive
		self.build = build
		self.graph = graph
		self.targets = graph.nodes.map { $0.value.value }
	}

	/// Starts the OutputPostprocessor
	func process() throws {
		let nodes = targets.compactMap { graph.findNode(for: $0) }
		let output = archive.appendingPathComponent("IR")

		try manager.createDirectory(at: output, withIntermediateDirectories: false)

		for node in nodes {
			let dependers = node.edges.filter { $0.relationship == .depender }

			guard dynamicDependencyToPath[node.value.productName] != nil || (dependers.count == 0 && !node.value.isSwiftPackage) else {
				continue
			}

			let irDirectory = output.appendingPathComponent(node.value.productName)
			let buildDirectory = build.appendingPathComponent(node.value.productName)

			// If there is a build directory for this target then copy the artifacts over to the IR
			// folder. Otherwise we will create an empty directory and that will contain the artifacts
			// of the dependency chain.
			if manager.directoryExists(at: buildDirectory) {
			    logger.debug("Copying \(node.value.guid) with name \(node.value.productName)")
				try manager.copyItem(at: buildDirectory, to: irDirectory)
			} else {
                logger.debug("No build directory for \(node.value.guid) with name \(node.value.productName)")
				try manager.createDirectory(at: irDirectory, withIntermediateDirectories: false)
			}

			// Copy over this target's static dependencies
			var processed: Set<Target> = []
			try copyDependencies(for: node.value, to: irDirectory, processed: &processed)
		}
	}

	private func copyDependencies(for target: Target, to irDirectory: URL, processed: inout Set<Target>) throws {
		guard processed.insert(target).inserted else {
			return
		}

		for node in graph.chain(for: target) {
			logger.debug("Processing Node: \(node.valueName)")

			// Do not copy dynamic dependencies
			guard dynamicDependencyToPath[node.value.productName] == nil else { continue }

			try copyDependencies(for: node.value, to: irDirectory, processed: &processed)

			let buildDirectory = build.appendingPathComponent(node.value.productName)
			if manager.directoryExists(at: buildDirectory) {
				do {
					try copyContentsOfDirectoryMergingDifferingFiles(at: buildDirectory, to: irDirectory)
				} catch {
					logger.debug("Copy error: \(error)")
				}
			}
		}
	}

	/// Copies the contents of a directory from source to destination, merging files that share the same name but differ in attributes
	/// - Parameters:
	///   - source: the source directory to copy the contents of
	///   - destination: the destination directory for the contents
	func copyContentsOfDirectoryMergingDifferingFiles(at source: URL, to destination: URL) throws {
		let files = try manager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)

		let sourceAndDestinations = files
			.map {
				(
					source: source.appendingPathComponent($0.lastPathComponent),
					destination: destination.appendingPathComponent($0.lastPathComponent)
				)
			}

		for (source, destination) in sourceAndDestinations where copiedFiles[destination, default: []].insert(source).inserted {
			// Avoid overwriting existing files with the same name.
			let uniqueDestinationURL = manager.uniqueFilename(directory: destination.deletingLastPathComponent(), filename: source.lastPathComponent)

			logger.debug("Copying source \(source) to destination: \(uniqueDestinationURL)")
			try manager.copyItem(at: source, to: uniqueDestinationURL)
		}
	}

	/// Returns a map of dynamic objects in the provided path
	/// - Parameter xcarchive: the path to search through
	/// - Returns: a mapping of filename to filepath for dynamic objects in the provided path
	private func dynamicDependencies(in xcarchive: URL) -> [String: URL] {
		let searchPath = baseSearchPath(startingAt: xcarchive)
		logger.debug("Using search path for dynamic dependencies: \(searchPath)")

		let dynamicDependencyExtensions = ["framework", "appex", "app"]

		return manager.filteredContents(of: searchPath, filter: { path in
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
				manager.directoryExists(at: path),
				let contents = try? manager.directories(at: path, recursive: false),
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
