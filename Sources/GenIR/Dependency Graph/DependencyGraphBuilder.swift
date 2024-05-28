//
//  DependencyGraphBuilder.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

/// A type that provides dependency relationships between values
protocol DependencyProviding {
	/// A type that represents the value of a node
	associatedtype Value: NodeValue

	/// Returns the direct dependencies for a given value
	/// - Parameter value: the value to get dependencies for
	/// - Returns: a list of dependencies
	func dependencies(for value: Value) -> [Value]
}

/// A builder for the DependencyGraph - you should _always_ use this class to build out the `DependencyGraph`
class DependencyGraphBuilder<Provider: DependencyProviding, Value: NodeValue> where Value == Provider.Value {
	/// The graph the builder will operate on
	typealias Graph = DependencyGraph<Value>

	/// The dependency provider
	private let provider: Provider

	/// The built graph
	let graph = Graph()

	/// Inits the Graph Builder
	/// - Parameters:
	///   - provider: the dependency provider for the values
	///   - values: the values to add to the graph
	init(provider: Provider, values: [Value]) {
		self.provider = provider
		values.forEach { add(value: $0) }
	}

	/// Adds a value (and it's dependencies) to the graph
	/// - Parameters:
	///   - value: the value to add
	@discardableResult
	private func add(value: Value) -> Graph.Node {
		if let existingNode = graph.findNode(for: value) {
			return existingNode
		}

		logger.debug("Adding value: \(value.valueName) to graph")

		let dependencies = provider.dependencies(for: value)
		let node = graph.addNode(for: value)

		for dependency in dependencies {
			let dependencyNode = add(value: dependency)

			node.add(edge: .init(to: dependencyNode, from: node, relationship: .dependency))
			dependencyNode.add(edge: .init(to: node, from: dependencyNode, relationship: .depender))
		}

		return node
	}
}
