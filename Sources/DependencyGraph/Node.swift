//
//  Node.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

import Foundation

public protocol NodeValue: Hashable {
	/// The name of this node, this should be unique
	var valueName: String { get }
}

extension DependencyGraph {
	/// A node holds an associated value and edges to other nodes in the graph
	public class Node {
		/// The edges from and to this node
		private(set) public var edges = [DependencyGraph.Edge]()

		/// The associated value of this node
		public let value: Value

		/// The name of this node
		public var valueName: String {
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
	public static func == (_ lhs: DependencyGraph.Node, rhs: DependencyGraph.Node) -> Bool {
		lhs.value == rhs.value && lhs.edges == rhs.edges
	}
}

extension DependencyGraph.Node: CustomStringConvertible {
	public var description: String {
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
	public func hash(into hasher: inout Hasher) {
		hasher.combine(valueName)
		hasher.combine(value)
	}
}
