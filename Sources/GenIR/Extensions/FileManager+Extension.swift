//
//  FileManager+Extension.swift
//
//
//  Created by Thomas Hedderwick on 29/07/2022.
//

import Foundation

extension FileManager {
	/// Returns a Boolean value that indicates whether a directory exists at the specified url
	/// - Parameter url: The url of the directory. This is tilde expanded
	/// - Returns: true if a directory exists at the specified path exists, or false if it doesn't exist or it does exist, but is a file
	func directoryExists(at url: URL) -> Bool {
		var bool = ObjCBool(false)
		let result: Bool

		result = FileManager.default.fileExists(
			atPath: (url.filePath as NSString).expandingTildeInPath,
			isDirectory: &bool
		)

		return result && bool.boolValue
	}

	/// Filters the contents of a directory based on the provided closure
	/// - Parameters:
	///   - path: the path to search through
	///   - properties: properties to pass to the DirectoryEnumerator
	///   - recursive: should search recursively
	///   - filter: a closure that filters the results
	/// - Returns: an filtered array of URL paths
	func filteredContents(
		of path: URL,
		properties: [URLResourceKey]? = nil,
		recursive: Bool = true,
		filter: (URL) throws -> Bool
	) rethrows -> [URL] {
		guard recursive else {
			let contents = (try? contentsOfDirectory(at: path, includingPropertiesForKeys: properties)) ?? []
			return try contents.filter(filter)
		}

		guard let enumerator = enumerator(at: path, includingPropertiesForKeys: properties) else {
			return []
		}

		return try enumerator.compactMap {
			if case let url as URL = $0 {
				return url
			}

			return nil
		}
		.filter { try filter($0) }
	}

	/// Returns an array of URL file paths found at the specified path ending in the specified suffix. If recursive is provided, a deep search of the path is performed
	/// - Parameters:
	///   - path: The path of the directory to search in
	///   - suffix: The suffix to match against file names
	///   - recursive: A Boolean value to indicate whether a recursive search should be performed
	/// - Returns: An array of URL file paths matching the suffix found in the specifed path
	func files(at path: URL, withSuffix suffix: String, recursive: Bool = true) throws -> [URL] {
		try filteredContents(of: path, recursive: recursive) { url in
			let attributes = try url.resourceValues(forKeys: [.isRegularFileKey])
			return attributes.isRegularFile ?? false && url.lastPathComponent.hasSuffix(suffix)
		}
	}

	/// Returns an array of URL paths found at the specified path that are directories
	/// - Parameters:
	///   - path: the path to search
	///   - recursive: should the search be recursive
	/// - Returns: An array of URL directory paths found in the specified path
	func directories(at path: URL, recursive: Bool = true) throws -> [URL] {
		try filteredContents(of: path, recursive: recursive, filter: { path in
			let attributes = try path.resourceValues(forKeys: [.isDirectoryKey])
			return attributes.isDirectory ?? false
		})
	}

	/// Creates a temporary directory with a given name
	/// - Parameter name: The name of the temporary directory
	/// - Returns: The URL of the created temporary directory
	func temporaryDirectory(named name: String) throws -> URL {
		let tempDirectory = NSTemporaryDirectory().appending(name).fileURL
		try createDirectory(at: tempDirectory, withIntermediateDirectories: true)

		return tempDirectory
	}

	/// Moves an item from source to destination, removing destination if it already exists
	/// - Parameters:
	///   - source: The item to move
	///   - destination: The destination to move the item to
	func moveItemReplacingExisting(from source: URL, to destination: URL) throws {
		if fileExists(atPath: destination.filePath) {
			try removeItem(at: destination)
		}

		try moveItem(at: source, to: destination)
	}

	/// Copies an item, merging with the existing path. Replacement of existing paths is performed if specified.
	/// - Parameters:
	///   - source: the item to copy
	///   - destination: the destination of the copy
	///   - replacing: should existing items be replaced?
	func copyItemMerging(at source: URL, to destination: URL, replacing: Bool = false) throws {
		let sourceFiles = try contentsOfDirectory(at: source, includingPropertiesForKeys: nil)

		for sourceFile in sourceFiles {
			let path = destination.appendingPathComponent(sourceFile.lastPathComponent)

			if replacing && fileExists(atPath: path.filePath) {
				try removeItem(at: path)
			}

			let destinationFile = uniqueFilename(directory: destination, filename: sourceFile.lastPathComponent)

			try copyItem(at: sourceFile, to: destinationFile)
		}
	}

	/// Generates a unique filename for a file at the given directory. This attempts to emulates finders style of appending a 'version' number at the end of the filename
	/// - Parameters:
	///   - directory: the directory the file would exist in
	///   - filename: the name of the file
	/// - Returns: a URL to a unique file in the given directory
	func uniqueFilename(directory: URL, filename: String) -> URL {
		var path = directory.appendingPathComponent(filename)
		var index = 2

		while fileExists(atPath: path.filePath) {
			let splitName = filename.split(separator: ".")

			if splitName.count == 2 {
				path = directory.appendingPathComponent("\(splitName[0]) \(index).\(splitName[1])")
			} else {
				path = directory.appendingPathComponent("\(filename) \(index)")
			}

			index += 1
		}

		return path
	}

	func destinationOfSymlinkExists(at path: URL) throws -> Bool {
		let attributes = try attributesOfItem(atPath: path.filePath)

		if let type = attributes[.type] as? FileAttributeType, type == .typeSymbolicLink {
			let destination = try destinationOfSymbolicLink(atPath: path.filePath)
			let actualDestinationCausePathingSucksInFoundation = path.deletingLastPathComponent().appendingPathComponent(destination)
			return fileExists(atPath: actualDestinationCausePathingSucksInFoundation.filePath)
		}

		return false
	}
}
