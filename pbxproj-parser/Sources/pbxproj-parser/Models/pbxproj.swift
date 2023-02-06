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

/// Represents a pbxproj file classure
class pbxproj: Decodable {
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

	/// Decodes a `pbxproj` object from the contents of `path`
	/// - Parameter path: path to `project.pbxproj` to parse
	/// - Returns: a deserialized pbxproj structure
	static func contentsOf(_ path: URL) throws -> pbxproj {
		let data = try Data(contentsOf: path)
		let decoder = PropertyListDecoder()
		let project = try decoder.decode(Self.self, from: data)
		project.fixup()
		return project
	}

	/// Fixes up `Object`s by unwrapping them and assigning the key that reprensents them to the reference field
	private func fixup() {
		_ = objects.map { (key, object) in
			object.unwrap().reference = key
		}
	}

	func object(key: String) -> PBXObject? {
		objects[key]?.unwrap()
	}

	func objects(of type: PBXObjectType) -> [PBXObject] {
		objects.compactMap { (_, value) -> PBXObject? in
			let object = value.unwrap()

			if object.isa == type {
				return object
			}

			return nil
		}
	}

	func project() -> PBXProject {
		guard let item = object(key: rootObject), let project = item as? PBXProject else {
			// TODO: throw useful errors here
			fatalError("The root object of the pbxproj doesn't exist... this shouldn't happen")
		}

		return project
	}

	func objects(for identifiers: [String]) -> [PBXObject] {
		identifiers.compactMap { object(key: $0) }
	}
}

class XCSwiftPackageProductDependency: Codable {}
