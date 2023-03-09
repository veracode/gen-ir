//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 27/01/2023.
//

import Foundation

/// Represents an xcworkspace - which is a set of xcodeproj bundles
struct XcodeWorkspace {
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
			project.targets.forEach { (name, _) in
				partialResult[name] = project
			}

			project.packages.forEach { (name, _) in
				partialResult[name] = project
			}
		})
	}

	/// Processes each underlying project to return a dictionary of their targets and products
	func targetsAndProducts() -> [String: String] {
		projects
			.map { $0.targetsAndProducts() }
			.reduce(into: [String: String]()) { partialResult, dict in
				// Keep existing keys and values in place
				partialResult.merge(dict, uniquingKeysWith: { (current, _) in current })
			}
	}
}

// swiftlint:disable private_over_fileprivate
fileprivate class XCWorkspaceDataParser: NSObject, XMLParserDelegate {
	let parser: XMLParser
	var projects = [String]()

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
		guard
			elementName == "FileRef",
			let location = attributeDict["location"]?.replacingOccurrences(of: "group:", with: ""),
			location.hasSuffix(".xcodeproj")
		else {
			return
		}

		projects.append(location)
	}
}
