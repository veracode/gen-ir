//
//  String+Extension.swift
//  
//
//  Created by Thomas Hedderwick on 04/07/2022.
//

import Foundation

extension String {
	/// Replacing double escapes with singles
	/// - Returns: the unescaped string
	func unescaped() -> String {
		self.replacingOccurrences(of: "\\\\", with: "\\")
	}

	/// Returns a file URL
	var fileURL: URL {
		if #available(macOS 13.0, *) {
			return .init(filePath: self)
		}

		return .init(fileURLWithPath: self)
	}

	/// Returns an array of all indices of a given substring, optionally starting from a specified index
	/// - Parameters:
	///   - substring: The substring to find the indices of
	///   - starting: The position in the string to start the search from
	/// - Returns: An array of indices representing the start index of substring matches
	func indices(of substring: String, from starting: Index? = nil) -> [Index] {
		var indices = [Index]()

		var current = starting ?? startIndex

		while
			current < endIndex,
			let range = range(of: substring, range: current..<endIndex),
			!range.isEmpty
		{
			indices.append(range.lowerBound)
			current = range.upperBound
		}

		return indices
	}

	/// Returns the first index of a character that hasn't been escaped
	/// - Parameters:
	///   - character: The character to search for
	///   - start: The starting position in the string to search from
	/// - Returns: The first index of the character found, or nil if it was not found
	func firstIndexWithEscapes(of character: Character, from start: Index? = nil) -> Index? {
		let startIndex = start ?? self.startIndex
		var substring = self[startIndex..<self.endIndex]

		while let index = substring.firstIndex(of: character) {
			guard index != startIndex else {
				return index
			}

			let previousIndex = substring.index(before: index)
			let range = substring.startIndex..<substring.endIndex

			if range.contains(previousIndex) {
				if substring[previousIndex] == "\\" {
					// move the search space forward
					substring = substring[substring.index(after: index)..<substring.endIndex]
					continue
				}
			}

			return index
		}

		return nil
	}
}
