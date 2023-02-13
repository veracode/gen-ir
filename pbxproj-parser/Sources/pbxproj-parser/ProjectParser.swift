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

		guard let project = project(for: target) else {
			logger.error("Failed to find project for target: \(project)")
			return []
		}

		// Search graph for dependencies
		logger.debug("graph: \(graph)")
		var dependencies = [PBXNativeTarget]()
		var nodesToVisit = graph.root.children

		for node in nodesToVisit {
			if !node.children.isEmpty {
				nodesToVisit.append(contentsOf: node.children)
			}

			if let dependency = node.object as? PBXNativeTarget {
				dependencies.append(dependency)
			} else {
				logger.error("Failed to cast node's object as PBXNativeTarget: \(node.object)")
			}
		}

		// Use the product reference to look up the FileReference path
		return dependencies
			.map { $0.productReference }
			.compactMap { project.object(for: $0, as: PBXFileReference.self) }
			.map { $0.path }
	}

	private func graph(for target: String) -> DependencyGraph? {
		switch type {
		case .project(let project): return project.dependencyGraphs[target]
		case .workspace(let workspace): return workspace.dependencyGraph(for: target)
		}
	}

	private func project(for target: String) -> XcodeProject? {
		switch type {
		case .project(let project): return project
		case .workspace(let workspace): return workspace.targetsToProject[target]
		}
	}
}
