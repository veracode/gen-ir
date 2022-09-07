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
		if #available(macOS 13.0, *) {
			return self.path()
		}

		return self.path
	}
}
