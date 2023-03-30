//
//  Collection+Extensions.swift
//
//
//  Created by Thomas Hedderwick on 30/03/2023.
//

import Foundation

// Largely based off the Collection.map impl in Swift
public extension Collection {
	func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
		let count = self.count
		if count == 0 {
			return []
		}

		var result = [T]()
		result.reserveCapacity(count)

		for element in self {
			try await result.append(transform(element))
		}

		return result
	}
}
