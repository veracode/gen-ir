//
//  Node.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

import Foundation

class Node {
	private(set) var neighbors: [Edge] = []
	let target: Target
	let name: String
	let uuid: UUID

	init(_ target: Target) {
		self.target = target
		self.name = target.name
		self.uuid = UUID()
	}

	func add(neighbor: Edge) {
		neighbors.append(neighbor)
	}
}

extension Node: Equatable {
	static func == (_ lhs: Node, rhs: Node) -> Bool {
		lhs.target == rhs.target && lhs.neighbors == rhs.neighbors
	}
}

extension Node: CustomStringConvertible {
	var description: String {
		var description = ""

		if !neighbors.isEmpty {
			description += "[Node: \(target.name), edges: \(neighbors.map { $0.neighbor.target.name})] "
		} else {
			description += "[Node: \(target.name)] "
		}

		return description
	}
}

extension Node: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(uuid)
	}
}
