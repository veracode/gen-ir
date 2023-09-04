//
//  DependencyGraphBuilder.swift
//
//
//  Created by Thomas Hedderwick on 28/08/2023.
//

class DependencyGraphBuilder {
	let targets: Targets

	init(targets: Targets) {
		self.targets = targets
	}

	func build() -> DependencyGraph {
		let graph = DependencyGraph()

		for target in targets {
			addToGraph(graph, target: target)
		}

		return graph
	}

	func addToGraph(_ graph: DependencyGraph, target: Target) {
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

			addToGraph(graph, target: dependencyTarget)

			guard let dependencyNode = graph.findNode(for: dependencyTarget) else {
				logger.debug("Couldn't find node for target (\(dependencyTarget.name)) even though it was just inserted?")
				continue
			}

			node.add(neighbor: .init(neighbor: dependencyNode))
		}
	}
}
