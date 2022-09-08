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

	/// Returns an array of URL file paths found at the specified path ending in the specified suffix. If recursive is provided, a deep search of the path is performed
	/// - Parameters:
	///   - path: The path of the directory to search in
	///   - suffix: The suffix to match against file names
	///   - recursive: A Boolean value to indicate whether a recursive search should be performed
	/// - Returns: An array of URL file paths matching the suffix found in the specifed path
	func files(at path: URL, withSuffix suffix: String, recursive: Bool = true) throws -> [URL] {
		guard recursive else {
			return try self.contentsOfDirectory(at: path, includingPropertiesForKeys: [.isRegularFileKey])
				.filter { $0.lastPathComponent.hasSuffix(suffix) }
		}

		guard let enumerator = self.enumerator(at: path, includingPropertiesForKeys: [.isRegularFileKey]) else {
			return []
		}

		var files = [URL]()
		for case let url as URL in enumerator {
			do {
				let attributes = try url.resourceValues(forKeys: [.isRegularFileKey])
				if let isFile = attributes.isRegularFile, isFile, url.lastPathComponent.hasSuffix(suffix) {
					files.append(url)
				}
			} catch {
				logger.error("files failed to get resource values for path: \(url) with error: \(error)")
			}
		}

		return files
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
}
