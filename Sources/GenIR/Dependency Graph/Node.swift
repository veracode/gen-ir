//
//  Node.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

import Foundation

class Node {
	/// The edges from and to this node
	private(set) var edges = [Edge]()
	/// The target this node represents
	let target: Target
	/// The name of this node, mostly used for debugging and printing
	let name: String

	init(_ target: Target) {
		self.target = target
		self.name = target.name
	}

	/// Adds an edge to this node
	/// - Parameter edge: the edge to add
	func add(edge: Edge) {
		edges.append(edge)
	}
}

extension Node: Equatable {
	static func == (_ lhs: Node, rhs: Node) -> Bool {
		lhs.target == rhs.target && lhs.edges == rhs.edges
	}
}

extension Node: CustomStringConvertible {
	var description: String {
		var description = ""

		if !edges.isEmpty {
			description += "[Node: \(target.name), edges: \(edges.map { $0.to.target.name})] "
		} else {
			description += "[Node: \(target.name)] "
		}

		return description
	}
}

extension Node: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(name)
		hasher.combine(target)
	}
}
