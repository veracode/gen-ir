//
//  DependencyGraph.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

import Foundation

/// A directed graph that maps dependencies between targets (nodes) via edges (directions between nodes)
class DependencyGraph {
	/// All the nodes in the graph
	private(set) var nodes: [Node] = []

	/// Adds a target to the graph
	/// - Parameter target: the target to add
	/// - Returns: the node added, iff a node for this target didn't already exist in the graph
	func addNode(target: Target) -> Node? {
		if findNode(for: target) != nil {
			return nil
		}

		let node = Node(target)
		nodes.append(node)
		return node
	}

	/// Finds a target's node in the graph
	/// - Parameter target: the target to look for
	/// - Returns: the node for the given target, if found
	func findNode(for target: Target) -> Node? {
		nodes.first(where: { $0.target == target })
	}

	/// Builds a dependency 'chain' for a target using a depth-first search
	/// - Parameter target: the target to get a chain for
	/// - Returns: the chain of nodes, starting
	func chain(for target: Target) -> [Node] {
		guard let targetNode = findNode(for: target) else {
			logger.debug("Couldn't find node for target: \(target.name)")
			return []
		}

		return depthFirstSearch(startingAt: targetNode)
	}

	func toDot(_ path: String) throws {
		var contents = "digraph DependencyGraph {\n"

		for node in nodes {
			for edge in node.edges.filter({ $0.relationship == .dependency }) {
				contents.append("\(node.name.replacingOccurrences(of: "-", with: "_")) -> \(edge.to.name.replacingOccurrences(of: "-", with: "_"))\n")
			}
		}

		contents.append("}")
		try contents.write(toFile: path, atomically: true, encoding: .utf8)
	}

	/// Perform a depth-first search starting at the provided node
	/// - Parameter node: the node whose children to search through
	/// - Returns: an array of nodes ordered by a depth-first search approach
	private func depthFirstSearch(startingAt node: Node) -> [Node] {
		logger.debug("----\nSearching for: \(node.target.name)")
		var visited = Set<Node>()
		var chain = [Node]()

		func depthFirst(node: Node) {
			logger.debug("inserting node: \(node.target.name)")
			visited.insert(node)
			logger.debug("visited: \(visited)")

			for edge in node.edges {
				logger.debug("edge to: \(edge.to)")
				if visited.insert(edge.to).inserted {
					logger.debug("inserted, recursing")
					depthFirst(node: edge.to)
				} else {
					logger.debug("edge already in visited: \(visited)")
				}
			}

			logger.debug("appending to chain: \(node.target.name)")
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
