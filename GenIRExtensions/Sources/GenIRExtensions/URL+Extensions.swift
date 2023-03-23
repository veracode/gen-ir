//
//  URL+Extension.swift
//  
//
//  Created by Thomas Hedderwick on 02/08/2022.
//

import Foundation

public extension URL {
	/// Returns the path component of a URL
	var filePath: String {
		return self.path
	}

	func appendingPath(component: String, isDirectory: Bool = false) -> URL {
		if #available(macOS 13.0, *) {
			return self.appending(component: component, directoryHint: isDirectory ? .isDirectory : .inferFromPath)
		} else {
			return self.appendingPathComponent(component, isDirectory: isDirectory)
		}
	}
}
