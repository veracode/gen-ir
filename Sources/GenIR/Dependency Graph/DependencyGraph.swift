//
//  DependencyGraph.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

class DependencyGraph {
	private(set) var nodes: [Node] = []

	func addNode(target: Target) -> Node? {
		// Don't add nodes we've already added
		if findNode(for: target) != nil {
			return nil
		}

		let node = Node(target)
		nodes.append(node)
		return node
	}

	func addEdge(from source: Node, to destination: Node) {
		source.add(neighbor: .init(neighbor: destination))
	}

	func findNode(for target: Target) -> Node? {
		nodes.first(where: { $0.target == target })
	}

	func search(_ target: Target) -> [Node] {
		guard let targetNode = findNode(for: target) else {
			logger.debug("Couldn't find node for target: \(target.name)")
			return []
		}

		return depthFirstSearch(startingAt: targetNode)
	}

	func depthFirstSearch(startingAt node: Node) -> [Node] {
		logger.info("----\nSearching for: \(node.target.name)")
		var visited = Set<Node>()
		var chain = [Node]()

		func depthFirst(node: Node) {
			logger.info("inserting node: \(node.target.name)")
			visited.insert(node)
			logger.info("visited: \(visited)")

			for edge in node.neighbors {
				logger.info("edge to: \(edge.neighbor)")
				if visited.insert(edge.neighbor).inserted {
					logger.info("inserted, recursing")
					depthFirst(node: edge.neighbor)
				} else {
					logger.info("edge already in visited: \(visited)")
				}
			}

			logger.info("appending to chain: \(node.target.name)")
			chain.append(node)
		}

		depthFirst(node: node)
		return chain
	}



	/// Builds a dependency chain in the order of which dependencies should be operated on
	/// - Parameter target: the target to build a chain for
	/// - Returns: an array of nodes, ordered in the way they should be operated on
	func buildChain(for target: Target) -> [Node]? {
		guard let targetNode = findNode(for: target) else {
			logger.debug("Couldn't find node for target: \(target.name)")
			return nil
		}

		func depthFirst(startingAt node: Node, visited: inout Set<Node>) -> [Node] {
			logger.debug("search ------\nstart: \(node). Visited: \(visited)")
			var chain = [node]
			visited.insert(node)

			for edge in node.neighbors where visited.insert(edge.neighbor).inserted {
				logger.debug("found edge: \(edge.neighbor).")
				chain += depthFirst(startingAt: edge.neighbor, visited: &visited)
			}

			return chain
		}

		/// do a depth first search
		var visited = Set<Node>()
		let chain = depthFirst(startingAt: targetNode, visited: &visited)

		print("chain: \(chain)")

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
