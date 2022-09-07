//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 04/07/2022.
//

import Foundation

extension String {
	/// Unescapes a backslash escaped string
	/// - Parameter string: the escaped string
	/// - Returns: an unescaped string
	func unescaped() -> String {
		self.replacingOccurrences(of: "\\\\", with: "\\")
	}

	var fileURL: URL {
		if #available(macOS 13.0, *) {
			return .init(filePath: self)
		}

		return .init(fileURLWithPath: self)
	}

	func indicies(of substring: String, from starting: Index? = nil) -> [Index] {
		var indicies = [Index]()

		var current = starting ?? startIndex

		while
			current < endIndex,
			let range = range(of: substring, range: current..<endIndex),
			!range.isEmpty
		{
			indicies.append(range.lowerBound)
			current = range.upperBound
		}

		return indicies
	}
}
