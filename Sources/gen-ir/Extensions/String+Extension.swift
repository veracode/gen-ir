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
		// We have to replace \ in strings otherwise they'll end up encoded into the URL and break resolution for paths with spaces
		return .init(fileURLWithPath: self.replacingOccurrences(of: "\\", with: ""))
	}

	/// Returns the first index of a character that hasn't been escaped
	/// - Parameters:
	///   - character: The character to search for
	///   - start: The starting position in the string to search from
	/// - Returns: The first index of the character found, or nil if it was not found
	func firstIndexWithEscapes(of character: Character, from start: Index? = nil) -> Index? {
		let startIndex = start ?? self.startIndex

		return self[startIndex..<self.endIndex].firstIndexWithEscapes(of: character, from: startIndex)
	}

	/// Splits a String ignoring matches where a split would normally occur, but is escaped with a \ character
	/// - Parameter separator: The separator to split on
	/// - Returns: An array of subsequences, split from the collection's elements
	func splitIgnoringEscapes(separator: Self.Element) -> [Self.SubSequence] {
		var results: [Self.SubSequence] = []
		var indices: [Self.Index] = []
		var offset = self.startIndex

		let substring = self[offset..<self.endIndex]

		while let index = substring.firstIndexWithEscapes(of: separator, from: offset) {
			indices.append(index)
			offset = substring.index(after: index)
		}

		if indices.isEmpty {
			// if no splits found, return the whole string as a single item array
			return [substring]
		}

		var startIndex = self.startIndex

		for index in indices {
			results.append(self[startIndex..<index])
			startIndex = substring.index(after: index)
		}

		return results
	}
}


extension Substring {
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
