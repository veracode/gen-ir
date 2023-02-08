import Foundation
import Logging

var logger: Logger = .init(label: "com.veracode.pbxproj_parser")

public struct ProjectParser {
	let path: URL
	let type: ProjectType

	public let targetsToProducts: [String: String]

	enum ProjectType {
		case project(XcodeProject)
		case workspace(XcodeWorkspace)
	}

	public enum Error: Swift.Error {
		case invalidProject(String)
	}

	public init(path: URL, logLevel level: Logger.Level) throws {
		self.path = path
		logger.logLevel = level

		if path.lastPathComponent.hasSuffix("xcodeproj") {
			self.type = .project(try XcodeProject(path: path))
		} else if path.lastPathComponent.hasSuffix("xcworkspace") {
			self.type = .workspace(try XcodeWorkspace(path: path))
		} else {
			throw Error.invalidProject("Path should be a xcodeproj or xcworkspace, got: \(path.lastPathComponent)")
		}

		switch type {
		case .project(let project):
			targetsToProducts = project.targetsAndProducts()
		case .workspace(let workspace):
			targetsToProducts = workspace.targetsAndProducts()
		}
	}

	public func dependencies(for target: String) -> [String] {
		guard let graph = graph(for: target) else {
			// TODO: make a fucking logger
			logger.error("Failed to find graph for target: \(target)")
			return []
		}

		// Search graph for dependencies
		logger.debug("graph: \(graph)")
		var dependencies = [PBXTarget]()
		var nodesToVisit = graph.root.children

		for node in nodesToVisit {
			if !node.children.isEmpty {
				nodesToVisit.append(contentsOf: node.children)
			}

			dependencies.append(node.object)
		}

		return dependencies.map { $0.nameOfProduct() }
	}

	private func graph(for target: String) -> DependencyGraph? {
		switch type {
		case .project(let project): return project.dependencyGraphs[target]
		case .workspace(let workspace): return workspace.dependencyGraph(for: target)
		}
	}
}
