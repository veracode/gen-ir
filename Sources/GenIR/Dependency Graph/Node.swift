//
//  Node.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

import Foundation

protocol NodeValue: Hashable {
	/// The name of this node, mostly used for debugging and printing
	var name: String { get }
}

class Node<Value: NodeValue> {
	/// The edges from and to this node
	private(set) var edges = [Edge<Value>]()
	/// The value this node represents
	let value: Value
	/// The name of this node, mostly used for debugging and printing
	let name: String

	init(_ value: Value) {
		self.value = value
		self.name = value.name
	}

	/// Adds an edge to this node
	/// - Parameter edge: the edge to add
	func add(edge: Edge<Value>) {
		if edges.filter({ $0.to.name == edge.to.name }).count == 0 {
			edges.append(edge)
		}
	}
}

extension Node: Equatable {
	static func == (_ lhs: Node, rhs: Node) -> Bool {
		lhs.value == rhs.value && lhs.edges == rhs.edges
	}
}

extension Node: CustomStringConvertible {
	var description: String {
		var description = ""

		if !edges.isEmpty {
			description += "[Node: \(value.name), edges: \(edges.filter({ $0.relationship == .dependency }).map { $0.to.value.name})] "
		} else {
			description += "[Node: \(value.name)] "
		}

		return description
	}
}

extension Node: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(name)
		hasher.combine(value)
	}
}
