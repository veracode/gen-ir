//
//  DependencyGraphBuilder.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

class DependencyGraphBuilder {
	/// Builds a dependency graph for the given collection of targets
	/// - Parameter targets: the targets to build a graph for
	/// - Returns: the dependency graph
	static func build(targets: Targets) -> DependencyGraph {
		let graph = DependencyGraph()

		for target in targets {
			add(target: target, in: targets, to: graph)
		}

		return graph
	}

	/// Adds a target (and it's dependencies) to the graph
	/// - Parameters:
	///   - graph: the graph to add a target to
	///   - target: the target to add
	///   - targets: the targets containing the target and it's dependencies
	static func add(target: Target, in targets: Targets, to graph: DependencyGraph) {
		logger.debug("Adding target: \(target.name) to graph")

		guard let node = graph.addNode(target: target) else {
			logger.debug("Already inserted node: \(target.name). Skipping.")
			return
		}

		let dependencies = targets.calculateDependencies(for: target)

		for dependency in dependencies {
			guard let dependencyTarget = targets.target(for: dependency) else {
				logger.debug("Couldn't lookup dependency in targets: \(dependency)")
				continue
			}

			add(target: dependencyTarget, in: targets, to: graph)

			guard let dependencyNode = graph.findNode(for: dependencyTarget) else {
				logger.debug("Couldn't find node for target (\(dependencyTarget.name)) even though it was just inserted?")
				continue
			}

			node.add(edge: .init(to: dependencyNode, from: node, relationship: .dependency))
			dependencyNode.add(edge: .init(to: node, from: dependencyNode, relationship: .depender))
		}
	}
}
