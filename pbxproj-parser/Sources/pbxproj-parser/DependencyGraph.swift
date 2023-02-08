//
//  DependencyGraph.swift
//  
//
//  Created by Thomas Hedderwick on 06/02/2023.
//

import Foundation

class DependencyGraph {
	private let model: pbxproj
	var root: Node

	init(_ target: PBXTarget, for project: pbxproj) {
		root = .init(object: target, model: project)
		model = project
	}

	class Node {
		let object: PBXTarget
		let model: pbxproj
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
			let node = Node(object: child, model: model)

			node.object.dependencies
				.compactMap({ model.object(key: $0) as? PBXTargetDependency })
				.compactMap({ model.object(key: $0.target) as? PBXNativeTarget })
				.forEach(insert)

			children.append(node)
		}
	}
}

extension DependencyGraph: CustomStringConvertible {
	var description: String {
		"""
		<Graph
			root: \(root)
		>
		"""
	}
}

extension DependencyGraph.Node: CustomStringConvertible {
	var description: String {
		"<Node object: \(object), children: \(children)>"
	}
}
