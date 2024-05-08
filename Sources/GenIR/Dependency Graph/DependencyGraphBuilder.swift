//
//  DependencyGraphBuilder.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

protocol DependencyProviding {
	associatedtype Value: NodeValue
	func dependencies(for value: Value) -> [Value]
}
class DependencyGraphBuilder<Value: NodeValue, Provider: DependencyProviding> where Value == Provider.Value {
	private let provider: Provider
	let graph = DependencyGraph<Value>()

	/// Inits the Graph Builder
	/// - Parameter provider: the dependency provider for the values
	init(provider: Provider, values: [Value]) {
		self.provider = provider
		values.forEach { add(value: $0) }
	}

	/// Adds a value (and it's dependencies) to the graph
	/// - Parameters:
	///   - value: the value to add
	@discardableResult
	private func add(value: Value) -> Node<Value> {
		logger.debug("Adding value: \(value.name) to graph")

		if let existingNode = graph.findNode(for: value) {
			logger.debug("Already inserted node: \(existingNode.name). Skipping")
			return existingNode
		}

		let dependencies = provider.dependencies(for: value)
		let node = graph.addNode(value: value)

		for dependency in dependencies {
			let dependencyNode = add(value: dependency)

			node.add(edge: .init(to: dependencyNode, from: node, relationship: .dependency))
			dependencyNode.add(edge: .init(to: node, from: dependencyNode, relationship: .depender))
		}

		return node
	}
}
