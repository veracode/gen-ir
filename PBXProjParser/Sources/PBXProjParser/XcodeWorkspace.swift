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
		let workspace = try WorkspaceParser.parse(path)
		let paths = workspace
				.fileReferences
				.map { $0.path }
				.filter { $0.hasSuffix("xcodeproj") }

		let baseFolder = path.deletingLastPathComponent()
		projectPaths = paths
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
