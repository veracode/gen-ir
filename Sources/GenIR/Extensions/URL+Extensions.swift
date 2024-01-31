//
//  URL+Extension.swift
//  
//
//  Created by Thomas Hedderwick on 02/08/2022.
//

import Foundation

extension URL {
	/// Returns the path component of a URL
	var filePath: String {
		return self.path
	}

	var fileExists: Bool {
		return FileManager().fileExists(atPath: self.filePath)
	}
}
