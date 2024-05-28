//
//  Edge.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

// swiftlint:disable identifier_name
/// An edge describes the relationship between two Node<Value>s in a graph

extension DependencyGraph {
	class Edge {
		/// The source node
		let to: DependencyGraph.Node
		/// The destination node
		let from: DependencyGraph.Node
		/// The relationship between the two nodes
		let relationship: Relationship

		/// Description of the relationships between two nodes
		enum Relationship {
			/// From depends on To
			case dependency
			/// From is a depender of To
			case depender
		}

		/// Initializes an edge between two nodes
		/// - Parameters:
		///   - to: the node this edge is pointing to
		///   - from: the node this edge is pointing from
		///   - relationship: the type of relationship this edge represents
		init(to: DependencyGraph.Node, from: DependencyGraph.Node, relationship: Relationship) {
			self.to = to
			self.from = from
			self.relationship = relationship
		}
	}
}

extension DependencyGraph.Edge: Equatable {
	static func == (_ lhs: DependencyGraph.Edge, rhs: DependencyGraph.Edge) -> Bool {
		lhs.to == rhs.to && lhs.from == rhs.from && lhs.relationship == rhs.relationship
	}
}

extension DependencyGraph.Edge: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(to)
		hasher.combine(from)
		hasher.combine(relationship)
	}
}

extension DependencyGraph.Edge: CustomStringConvertible {
	var description: String { "[Edge from \(from) to \(to) relationship: \(relationship)]"}
}
// swiftlint:enable identifier_name
