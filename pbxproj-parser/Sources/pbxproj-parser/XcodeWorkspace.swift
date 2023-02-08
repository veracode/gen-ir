//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 27/01/2023.
//

import Foundation

struct XcodeWorkspace {
	/// Path to the Workspace
	let path: URL
	private let contentsPath: URL

	private(set) var projectPaths: [URL]
	let models: [URL: XcodeProject]
	let targetsToProject: [String: XcodeProject]

	init(path: URL) throws {
		// Parse the `contents.xcworkspacedata` file and get the list of projects
		self.path = path
		contentsPath = path.appendingPathComponent("contents.xcworkspacedata")

		// Parse the contents path (XML) to get a list of pbxproj's
		let data = try Data(contentsOf: contentsPath)
		let parser = XCWorkspaceDataParser(data: data)

		let baseFolder = path.deletingLastPathComponent()
		projectPaths = parser.projects
			.map { baseFolder.appendingPathComponent($0, isDirectory: true) }

		models = try projectPaths.reduce(into: [URL: XcodeProject](), { partialResult, path in
			partialResult[path] = try .init(path: path)
		})

		targetsToProject = models.values.reduce(into: [String: XcodeProject](), { partialResult, project in
			project.targets.forEach {
				partialResult[$0.nameOfProduct()] = project
			}
		})
	}

	func targetsAndProducts() -> [String: String] {
		models.values
			.map { $0.targetsAndProducts() }
			.reduce(into: [String: String]()) { partialResult, dict in
				// Keep existing keys and values in place
				partialResult.merge(dict, uniquingKeysWith: { (current, _) in current })
			}
	}

	func dependencyGraph(for target: String) -> DependencyGraph? {
		targetsToProject[target]?.dependencyGraphs[target]
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
			var location = attributeDict["location"]?.replacingOccurrences(of: "group:", with: ""),
			location.hasSuffix(".xcodeproj")
		else {
			return
		}

		projects.append(location)
	}
}
