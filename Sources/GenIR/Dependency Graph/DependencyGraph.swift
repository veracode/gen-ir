//
//  DependencyGraph.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

import Foundation

/// A directed graph that maps dependencies between values (nodes) via edges (directions between nodes)
class DependencyGraph<Value: NodeValue> {
	/// All the nodes in the graph
	private(set) var nodes = [String: Node<Value>]()

	/// Adds a value to the graph
	/// - Parameter value: the value to add
	/// - Returns: the node added
	func addNode(value: Value) -> Node<Value> {
		if let node = findNode(for: value) {
			return node
		}

		let node = Node<Value>(value)
		nodes[value.valueName] = node
		return node
	}

	/// Finds a value's node in the graph
	/// - Parameter value: the value to look for
	/// - Returns: the node for the given value, if found
	func findNode(for value: Value) -> Node<Value>? {
		nodes[value.valueName]
	}

	/// Builds a dependency 'chain' for a value using a depth-first search
	/// - Parameter value: the value to get a chain for
	/// - Returns: the chain of nodes, starting
	func chain(for value: Value) -> [Node<Value>] {
		guard let node = findNode(for: value) else {
			logger.debug("Couldn't find node for value: \(value.valueName)")
			return []
		}

		return depthFirstSearch(startingAt: node)
	}

	func toDot(_ path: String) throws {
		var contents = "digraph DependencyGraph {\n"

		for node in nodes.values {
			for edge in node.edges.filter({ $0.relationship == .dependency }) {
				func dotSanitized(for name: String) -> String {
					name
						.replacingOccurrences(of: "-", with: "_")
						.replacingOccurrences(of: ".", with: "_")
				}
				contents.append("\(dotSanitized(for: node.valueName)) -> \(dotSanitized(for: edge.to.valueName))\n")
			}
		}

		contents.append("}")
		try contents.write(toFile: path, atomically: true, encoding: .utf8)
	}

	/// Perform a depth-first search starting at the provided node
	/// - Parameter node: the node whose children to search through
	/// - Returns: an array of nodes ordered by a depth-first search approach
	private func depthFirstSearch(startingAt node: Node<Value>) -> [Node<Value>] {
		logger.debug("----\nSearching for: \(node.value.valueName)")
		var visited = Set<Node<Value>>()
		var chain = [Node<Value>]()

		func depthFirst(node: Node<Value>) {
			logger.debug("inserting node: \(node.value.valueName)")
			visited.insert(node)
			logger.debug("visited: \(visited)")

			for edge in node.edges where edge.relationship == .dependency {
				logger.debug("edge to: \(edge.to)")
				if visited.insert(edge.to).inserted {
					logger.debug("inserted, recursing")
					depthFirst(node: edge.to)
				} else {
					logger.debug("edge already in visited: \(visited)")
				}
			}

			logger.debug("appending to chain: \(node.value.valueName)")
			chain.append(node)
		}

		depthFirst(node: node)
		return chain
	}
}

extension DependencyGraph: CustomStringConvertible {
	var description: String {
		var description = ""

		nodes
			.forEach {
				description += "[\($0)]"
			}

		return description
	}
}
