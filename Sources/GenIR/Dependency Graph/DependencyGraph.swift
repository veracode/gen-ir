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
	private(set) var nodes = [String: Node]()

	/// Adds a node for the associated value to the graph
	/// - Parameter value: the value associated with the node
	/// - Returns: the node for the associated value. If the node already existed it is returned
	func addNode(for value: Value) -> Node {
		if let node = findNode(for: value) {
			return node
		}

		let node = Node(value)
		nodes[value.valueName] = node
		return node
	}

	/// Finds the node associated with a value
	/// - Parameter value: the value to look for
	/// - Returns: the node for which the value is associated, if found
	func findNode(for value: Value) -> Node? {
		nodes[value.valueName]
	}

	/// Returns the dependency 'chain' for the value associated with a node in the graph using a depth-first search
	/// - Parameter value: the associated value for a node to start the search with
	/// - Returns: the chain of nodes, starting with the 'bottom' of the dependency subgraph
	func chain(for value: Value) -> [Node] {
		guard let node = findNode(for: value) else {
			logger.debug("Couldn't find node for value: \(value.valueName)")
			return []
		}

		return depthFirstSearch(startingAt: node)
	}

	/// Perform a depth-first search starting at the provided node
	/// - Parameter node: the node whose children to search through
	/// - Returns: an array of nodes ordered by a depth-first search approach
	private func depthFirstSearch(startingAt node: Node) -> [Node] {
		logger.debug("----\nSearching for: \(node.value.valueName)")
		var visited = Set<Node>()
		var chain = [Node]()

		/// Visits node dependencies and adds them to the chain from the bottom up
		/// - Parameter node: the node to search through
		func depthFirst(node: Node) {
			logger.debug("inserting node: \(node.value.valueName)")
			visited.insert(node)

			for edge in node.edges where edge.relationship == .dependency {
				if visited.insert(edge.to).inserted {
					logger.debug("edge to: \(edge.to)")
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

	/// Writes a 'dot' graph file to disk
	/// - Parameter path: the path to write the graph to
	func toDot(_ path: String) throws {
		var contents = "digraph DependencyGraph {\n"

		for node in nodes.values {
			for edge in node.edges.filter({ $0.relationship == .dependency }) {
				contents.append("\"\(node.valueName)\" -> \"\(edge.to.valueName)\"\n")
			}
		}

		contents.append("}")
		try contents.write(toFile: path, atomically: true, encoding: .utf8)
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
