//
//  XcodeWorkspace.swift
//
//
//  Created by Thomas Hedderwick on 27/01/2023.
//

import Foundation

/// Represents an xcworkspace - which is a set of xcodeproj bundles
class XcodeWorkspace {
	/// Path to the Workspace
	let path: URL
	/// Path to the various underlying xcodeproj bundles
	private(set) var projectPaths: [URL]
	/// List of projects this workspace references
	let projects: [XcodeProject]

	/// A mapping of targets to the projects that define them
	let targetsToProject: [String: XcodeProject]

	init(path: URL) throws {
		self.path = path

		// Parse the `contents.xcworkspacedata` (XML) file and get the list of projects
		let contentsPath = path.appendingPathComponent("contents.xcworkspacedata")

		let data = try Data(contentsOf: contentsPath)
		let parser = XCWorkspaceDataParser(data: data)

		let baseFolder = path.deletingLastPathComponent()
		projectPaths = parser.projects
			.map { baseFolder.appendingPathComponent($0, isDirectory: true) }

		projects = try projectPaths.map(XcodeProject.init(path:))

		targetsToProject = projects.reduce(into: [String: XcodeProject](), { partialResult, project in
			project.targets.forEach { (target) in
				partialResult[target.name] = project
				if let productName = target.productName, productName != target.name {
					partialResult[productName] = project
				}
			}

			project.packages.forEach { (target) in
				partialResult[target.productName] = project
			}
		})
	}

	/// All native targets in the workspace
	var targets: [PBXNativeTarget] {
		projects.flatMap { $0.targets }
	}

	/// All packages in the workspace
	var packages: [XCSwiftPackageProductDependency] {
		projects.flatMap { $0.packages }
	}
}

// swiftlint:disable private_over_fileprivate
/// A xcworkspace parser
fileprivate class XCWorkspaceDataParser: NSObject, XMLParserDelegate {
	let parser: XMLParser
	var projects = [String]()

	var isInGroup = false
	var currentGroupPath: [String] = []

	let groupTag = "Group"
	let fileRefTag = "FileRef"

	init(data: Data) {
		parser = .init(data: data)

		super.init()

		parser.delegate = self
		parser.parse()
	}

	func parser(
		_ parser: XMLParser,
		didStartElement elementName: String,
		namespaceURI: String?,
		qualifiedName qName: String?,
		attributes attributeDict: [String: String] = [:]
	) {
		switch elementName {
		case groupTag:
			handleGroupTag(attributeDict)
		case fileRefTag:
			handleFileRefTag(attributeDict)
		default:
			break
		}
	}

	/// Returns the location attribute value from the provided attributes, if one exists
	/// - Parameter attributeDict: the attribute dictionary to extract a location attribute from
	/// - Returns: the path of the location attribute value
	private func extractLocation(_ attributeDict: [String: String]) -> String? {
		guard let location = attributeDict["location"] else { return nil }

		if location.starts(with: "group:") {
			return location.replacingOccurrences(of: "group:", with: "")
		} else if location.starts(with: "container:") {
			let location = location.replacingOccurrences(of: "container:", with: "")

			if !location.isEmpty { return location }

			// Sometimes, location could be empty, in this case _normally_ you'll have a name attribute
			return attributeDict["name"]
		}

		return nil
	}

	/// Handle a Group tag
	///
	/// Group tags require additional logic - since they can contain nested child paths via either additional group tags or file ref tags.
	/// Set a flag in this function that's handled in `handleFileRefTag(_:)`
	/// - Parameter attributeDict: the attributes attached to this tag
	private func handleGroupTag(_ attributeDict: [String: String]) {
		// For groups, we want to track the 'sub' path as we go deeper into the tree,
		// this will allow us to create 'full' paths as we see file refs
		guard let location = extractLocation(attributeDict) else { return }
		currentGroupPath.append(location)
		isInGroup = true
	}

	/// Handle a FileRef tag
	///
	/// Since Group tags can build out parts of paths, we also handle cases where this file ref is part of a group structure.
	/// - Parameter attributeDict: the attributes attached to this tag
	private func handleFileRefTag(_ attributeDict: [String: String]) {
		// For file refs, we have two options - if we're not in a group we can just use the path as-is.
		// If we're in a group, we will need to construct the current path from the depth we're currently in
		guard
			let location = extractLocation(attributeDict),
			location.hasSuffix(".xcodeproj")
		else { return }

		if isInGroup {
			// Add a '/' in between group subpaths, then add the current location to the end
			let fullLocation = currentGroupPath.reduce(into: "") { $0.append($1); $0.append("/") }.appending(location)
			projects.append(fullLocation)
		} else {
			projects.append(location)
		}
	}

	func parser(
		_ parser: XMLParser,
		didEndElement elementName: String,
		namespaceURI: String?,
		qualifiedName qName: String?
	) {
		// If we're ending a group tag, we can pop the matching group off of the stack as we're done with it
		guard elementName == groupTag else { return }

		_ = currentGroupPath.popLast()

		isInGroup = !currentGroupPath.isEmpty
	}
}
// swiftlint:enable private_over_fileprivate
