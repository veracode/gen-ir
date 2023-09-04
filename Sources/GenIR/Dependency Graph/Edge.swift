//
//  Edge.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

class Edge {
	let neighbor: Node

	init(neighbor: Node) {
		self.neighbor = neighbor
	}
}

extension Edge: Equatable {
	static func == (_ lhs: Edge, rhs: Edge) -> Bool {
		lhs.neighbor == rhs.neighbor
	}
}

extension Edge: CustomStringConvertible {
	var description: String { "[Edge: \(neighbor)]"}
}
