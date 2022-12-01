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
