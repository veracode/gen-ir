//
//  pbxproj.swift
//  
//
//  Created by Thomas Hedderwick on 27/01/2023.
//

import Foundation

/*
 Note: This is based _largely_ on prior art. Thanks to:
	http://www.monobjc.net/xcode-project-file-format.html
	Cocoapods

 Some of the references here are reverse engineered from the `XCBuild.framework` from Xcode:
 /Applications/Xcode.app/Contents/SharedFrameworks/XCBuild.framework/Versions/A/PlugIns/XCBBuildService.bundle/Contents/Frameworks/XCBProjectModel.framework/Versions/A/XCBProjectModel
 */

// NOTE! Big thanks to http://www.monobjc.net/xcode-project-file-format.html for the file format reference - a lot of the layout here is based on that work

/// Represents a pbxproj file
class PBXProj: Decodable {
	/// Version of the pbxproj
	let archiveVersion: String
	/// ???
	let classes: [String: String]
	/// Version of the `objects`
	let objectVersion: String
	///  Mapping of UUID to their corresponding object
	let objects: [String: Object]
	/// UUID of the root object (probably a PBXProject
	let rootObject: String

	enum Error: Swift.Error {
		case projectNotFound(String)
	}

	/// Decodes a `pbxproj` object from the contents of `path`
	/// - Parameter path: path to `project.pbxproj` to parse
	/// - Returns: a deserialized pbxproj structure
	static func contentsOf(_ path: URL) throws -> PBXProj {
		let data = try Data(contentsOf: path)
		let decoder = PropertyListDecoder()
		let project = try decoder.decode(Self.self, from: data)
		project.fixup()
		return project
	}

	/// Fixes `Object`s by unwrapping them and assigning the key that represents them to the reference field
	private func fixup() {
		objects.forEach { (key, object) in
			object.unwrap().reference = key
		}
	}
}

extension PBXProj {
	func object<T>(forKey key: String, as type: T.Type = T.Type) -> T? {
		objects[key]?.unwrap() as? T
	}

	func objects<T>(of type: PBXObjectType) -> [T] {
		objects.compactMap { (_, value) -> T? in
			let object = value.unwrap()

			if object.isa == type {
				return object as? T
			}

			return nil
		}
	}

	func objects<T>(of objectType: PBXObjectType, as type: T.Type) -> [T] {
		objects.compactMap { (_, value) -> T? in
			let object = value.unwrap()

			if object.isa == objectType {
				return object as? T
			}

			return nil
		}
	}

	func project() throws -> PBXProject {
		guard let project: PBXProject = object(forKey: rootObject) else {
			throw Error.projectNotFound(
				"The root object of the pbxproj doesn't exist, or isn't castable to PBXProject... this shouldn't happen"
			)
		}

		return project
	}

	func objects<T>(for identifiers: [String]) -> [T] {
		identifiers.compactMap { object(forKey: $0) }
	}
}
