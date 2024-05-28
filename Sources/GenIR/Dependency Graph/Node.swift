//
//  Node.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

import Foundation

protocol NodeValue: Hashable {
	/// The name of this node, this should be unique
	var valueName: String { get }
}

extension DependencyGraph {
	class Node {
		/// The edges from and to this node
		private(set) var edges = [DependencyGraph.Edge]()

		/// The associated value of this node
		let value: Value

		/// The name of this node
		var valueName: String {
			value.valueName
		}

		/// Initializes a node with an associated value
		/// - Parameter value: the value to associate with this node
		init(_ value: Value) {
			self.value = value
		}

		/// Adds an edge to this node
		/// - Parameter edge: the edge to add
		func add(edge: DependencyGraph.Edge) {
			if edges.filter({ $0.to.valueName == edge.to.valueName }).count == 0 {
				edges.append(edge)
			}
		}
	}
}

extension DependencyGraph.Node: Equatable {
	static func == (_ lhs: DependencyGraph.Node, rhs: DependencyGraph.Node) -> Bool {
		lhs.value == rhs.value && lhs.edges == rhs.edges
	}
}

extension DependencyGraph.Node: CustomStringConvertible {
	var description: String {
		var description = ""

		if !edges.isEmpty {
			description += "[Node: \(value.valueName), edges: \(edges.filter({ $0.relationship == .dependency }).map { $0.to.value.valueName})] "
		} else {
			description += "[Node: \(value.valueName)] "
		}

		return description
	}
}

extension DependencyGraph.Node: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(valueName)
		hasher.combine(value)
	}
}
