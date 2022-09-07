//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 29/07/2022.
//

import Foundation

extension FileManager {
	func directoryExists(at url: URL) -> Bool {
		var bool = ObjCBool(false)
		let result: Bool
		
		if #available(macOS 13.0, *) {
			result = FileManager.default.fileExists(
				atPath: (url.path() as NSString).expandingTildeInPath,
				isDirectory: &bool
			)
		} else {
			result = FileManager.default.fileExists(
				atPath: (url.path as NSString).expandingTildeInPath,
				isDirectory: &bool
			)
		}
		
		return result && bool.boolValue
	}
	
	func getFiles(at path: URL, withSuffix suffix: String, recursive: Bool = true) throws -> [URL] {
		if !recursive {
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
				if let isFile = attributes.isRegularFile, isFile {
					files.append(url)
				}
			} catch {
				print("getFiles error: \(error) for path: \(url)")
			}
		}
		
		return files
	}
}
