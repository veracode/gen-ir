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
public class PBXProj: Decodable {
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
		let data: Data

		do {
			data = try Data(contentsOf: path)
		} catch {
			logger.error("Failed to get contents of path: \(path), please check that this path exists and is readable.")
			throw error
		}

		let decoder = PropertyListDecoder()

		do {
			let project = try decoder.decode(Self.self, from: data)
			project.fixup()
			return project
		} catch {
			logger.error(
				"Failed to decode the pbxproj for path: \(path). Please report this as an error with the pbxproj!"
			)
			throw error
		}
	}

	/// Fixes `Object`s by unwrapping them and assigning the UUID key that represents them to the reference field
	private func fixup() {
		objects.forEach { (key, object) in
			object.unwrap().reference = key
		}
	}
}

/// Helper functions for operating on the project structure
public extension PBXProj {
	/// Returns the object for a given key as the given type
	/// - Parameters:
	///   - key: the reference key for the object
	///   - type: the type the object should be cast to
	/// - Returns: the object, if the reference exists and the type conversion succeeded. Otherwise, nil.
	func object<T>(forKey key: String, as type: T.Type = T.self) -> T? {
		objects[key]?.unwrap() as? T
	}

	/// Returns all the objects of a given type in the project structure
	/// - Parameter objectType: the type of objects to find
	/// - Parameter type: the type to cast the object to
	/// - Returns: an array of all the typed objects found in the project structure
	func objects<T>(of objectType: PBXObject.ObjectType, as type: T.Type) -> [T] {
		objects
			.map { $1.unwrap() }
			.filter { $0.isa == objectType }
			.compactMap { $0 as? T }
	}

	func project() throws -> PBXProject {
		guard let project: PBXProject = object(forKey: rootObject) else {
			throw Error.projectNotFound(
				"The root object of the pbxproj doesn't exist, or isn't castable to PBXProject... this shouldn't happen"
			)
		}

		return project
	}

	/// Returns a list of objects for a given list of references
	/// - Parameter references: a list of references to lookup
	/// - Returns: a list of objects that matches a reference in the references list
	func objects<T>(for references: [String]) -> [T] {
		references.compactMap { object(forKey: $0) }
	}
}
