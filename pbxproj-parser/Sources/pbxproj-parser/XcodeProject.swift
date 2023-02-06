//
//  XcodeProject.swift
//  
//
//  Created by Thomas Hedderwick on 27/01/2023.
//

import Foundation

enum ParsingError: Error {
	case missingKey(String)
	case validationError(String)
}

public struct XcodeProject {
	/// Path to the Workspace
	public let path: URL
	private let pbxprojPath: URL
	private let model: pbxproj

	let project: PBXProject
	let targets: [PBXTarget]
	var dependencyGraphs: [String: DependencyGraph] = [:]

	public init(path: URL) throws {
		self.path = path
		pbxprojPath = path.appendingPathComponent("project.pbxproj")
		model = try pbxproj.contentsOf(pbxprojPath)

		project = model.project()
		targets = model.objects(for: project.targets).compactMap { $0 as? PBXTarget }

		dependencyGraphs = targets.reduce(into: [String: DependencyGraph](), { partialResult, target in
			partialResult[target.reference] = .init(target, for: model)
		})
	}

	func targetsAndProducts() -> [String: String] {
		targets.reduce(into: [String: String]()) { partialResult, target in
			partialResult[target.name] = target.productName ?? target.name
		}
	}
}

class DependencyGraph {
	private let model: pbxproj
	var root: Node

	init(_ target: PBXTarget, for project: pbxproj) {
		root = .init(object: target, model: project)
		model = project
	}

	class Node {
		let object: PBXTarget
		let model: pbxproj // TODO: Welp, my poor memory bytes. Will the COWs rise up and take us?
		var children: [Node] = []

		init(object: PBXTarget, model: pbxproj) {
			self.object = object
			self.model = model

			self.object.dependencies
				.compactMap({ model.object(key: $0) as? PBXTargetDependency })
				.compactMap({ model.object(key: $0.target) as? PBXNativeTarget })
				.forEach(insert)
		}

		func insert(_ child: PBXTarget) {
			var node = Node(object: child, model: model)

			node.object.dependencies
				.compactMap({ model.object(key: $0) as? PBXTargetDependency })
				.compactMap({ model.object(key: $0.target) as? PBXNativeTarget })
				.forEach(insert)

			children.append(node)
		}
	}
}

