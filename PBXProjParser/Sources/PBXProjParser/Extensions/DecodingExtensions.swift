//
//  DecodingExtensions.swift
//  
//
//  Created by Thomas Hedderwick on 03/02/2023.
//

import Foundation

// https://gist.github.com/mikebuss/17142624da4baf9cdcc337861e256533

struct PlistCodingKeys: CodingKey {
	var stringValue: String

	init(stringValue: String) {
		self.stringValue = stringValue
	}

	var intValue: Int?

	init?(intValue: Int) {
		self.init(stringValue: "\(intValue)")
		self.intValue = intValue
	}
}

extension KeyedDecodingContainer {
	func decode(_ type: [String: Any].Type, forKey key: K) throws -> [String: Any] {
		let container = try self.nestedContainer(keyedBy: PlistCodingKeys.self, forKey: key)
		return try container.decode(type)
	}

	func decodeIfPresent(_ type: [String: Any].Type, forKey key: K) throws -> [String: Any]? {
		return try? self.nestedContainer(keyedBy: PlistCodingKeys.self, forKey: key).decode(type)
	}

	func decode(_ type: [Any].Type, forKey key: K) throws -> [Any] {
		var container = try self.nestedUnkeyedContainer(forKey: key)
		return try container.decode(type)
	}

	func decodeIfPresent(_ type: [Any].Type, forKey key: K) throws -> [Any]? {
		guard var container = try? self.nestedUnkeyedContainer(forKey: key) else {
			return nil
		}

		return try? container.decode(type)
	}

	func decode(_ type: [String: Any].Type) throws -> [String: Any] {
		var dictionary = [String: Any]()

		for key in allKeys {
			if let boolValue = try? decode(Bool.self, forKey: key) {
				dictionary[key.stringValue] = boolValue
			} else if let stringValue = try? decode(String.self, forKey: key) {
				dictionary[key.stringValue] = stringValue
			} else if let intValue = try? decode(Int.self, forKey: key) {
				dictionary[key.stringValue] = intValue
			} else if let doubleValue = try? decode(Double.self, forKey: key) {
				dictionary[key.stringValue] = doubleValue
			} else if let nestedDictionary = try? decode([String: Any].self, forKey: key) {
				dictionary[key.stringValue] = nestedDictionary
			} else if let nestedArray = try? decode([Any].self, forKey: key) {
				dictionary[key.stringValue] = nestedArray
			}
		}
		return dictionary
	}
}

extension UnkeyedDecodingContainer {
	mutating func decode(_ type: [Any].Type) throws -> [Any] {
		var array: [Any] = []

		while isAtEnd == false {
			let value: String? = try decode(String?.self)
			if value == nil {
				continue
			}
			if let value = try? decode(Bool.self) {
				array.append(value)
			} else if let value = try? decode(Int.self) {
				array.append(value)
			} else if let value = try? decode(Double.self) {
				array.append(value)
			} else if let value = try? decode(String.self) {
				array.append(value)
			} else if let nestedDictionary = try? decode([String: Any].self) {
				array.append(nestedDictionary)
			} else if let nestedArray = try? decode([Any].self) {
				array.append(nestedArray)
			}
		}
		return array
	}

	mutating func decode(_ type: [String: Any].Type) throws -> [String: Any] {
		let nestedContainer = try self.nestedContainer(keyedBy: PlistCodingKeys.self)
		return try nestedContainer.decode(type)
	}
}
