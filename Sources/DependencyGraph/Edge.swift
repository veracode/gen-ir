//
//  Edge.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

// swiftlint:disable identifier_name
/// An edge describes the relationship between two Node<Value>s in a graph

extension DependencyGraph {
	/// An edge represents the connection between two nodes in the graph
	public class Edge {
		/// The source node
		public let to: DependencyGraph.Node
		/// The destination node
		public let from: DependencyGraph.Node
		/// The relationship between the two nodes
		public let relationship: Relationship

		/// Description of the relationships between two nodes
		public enum Relationship {
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
	public static func == (_ lhs: DependencyGraph.Edge, rhs: DependencyGraph.Edge) -> Bool {
		lhs.to == rhs.to && lhs.from == rhs.from && lhs.relationship == rhs.relationship
	}
}

extension DependencyGraph.Edge: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(to)
		hasher.combine(from)
		hasher.combine(relationship)
	}
}

extension DependencyGraph.Edge: CustomStringConvertible {
	public var description: String { "[Edge from \(from) to \(to) relationship: \(relationship)]"}
}
// swiftlint:enable identifier_name
