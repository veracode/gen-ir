//
//  Edge.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

// swiftlint:disable identifier_name
/// An edge describes the relationship between two Node<Value>s in a graph
class Edge<Value: NodeValue> {
	/// The source node
	let to: Node<Value>
	/// The destination node
	let from: Node<Value>
	/// The relationship between the two nodes
	let relationship: Relationship

	/// Description of the relationships between two nodes
	enum Relationship {
		/// From depends on To
		case dependency
		/// From is a depender of To
		case depender
	}

	init(to: Node<Value>, from: Node<Value>, relationship: Relationship) {
		self.to = to
		self.from = from
		self.relationship = relationship
	}
}

extension Edge: Equatable {
	static func == (_ lhs: Edge, rhs: Edge) -> Bool {
		lhs.to == rhs.to && lhs.from == rhs.from && lhs.relationship == rhs.relationship
	}
}

extension Edge: CustomStringConvertible {
	var description: String { "[Edge from \(from) to \(to) relationship: \(relationship)]"}
}
// swiftlint:enable identifier_name
