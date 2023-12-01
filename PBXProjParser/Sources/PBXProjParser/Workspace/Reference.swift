//
//  Reference.swift
//
//
//  Created by Thomas Hedderwick on 18/10/2023.
//
import Foundation

protocol Reference {
	var location: Location { get }
	static var elementName: String { get }
}

enum Location {
	// TODO: Find where we can get a definitive list of these. Xcode must have them somewhere?
	case container(String)
	case group(String)

	enum Error: Swift.Error {
		case invalidLocation(String)
	}

	init(_ location: String) throws {
		let split = location
			.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
			.map(String.init)

		guard
			let key = split.first,
			let value = split.last
		else { throw Error.invalidLocation("Couldn't extract key/value pair from split: \(split)") }

		switch key {
		case "container": self = .container(value)
		case "group":     self = .group(value)
		default: throw Error.invalidLocation("Key didn't match a supported location key: \(key)")
		}
	}

	var path: String {
		switch self {
		case .container(let path): return path
		case .group(let path):     return path
		}
	}
}

class Group: Reference {
	static let elementName: String = "Group"

	let location: Location
	let name: String?
	var references: [Reference] = []

	init(location: String, name: String?) throws {
		self.location = try .init(location)
		self.name = name
	}
}

struct FileRef: Reference {
	static let elementName: String = "FileRef"

	let location: Location
	let enclosingGroup: Group?

	init(location: String, enclosingGroup: Group? = nil) throws {
		self.location = try .init(location)
		self.enclosingGroup = enclosingGroup
	}

	var path: String {
		guard
			let enclosingGroup
		else { return location.path }

		switch enclosingGroup.location {
		case let .group(path), let .container(path):
			if path.last == "/" {
				return path + location.path
			}

			return path + "/" + location.path
		}
	}
}
