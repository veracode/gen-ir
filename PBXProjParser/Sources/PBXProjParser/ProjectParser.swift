import Foundation
import Logging

var logger: Logger = .init(label: "com.veracode.pbxproj_parser")

public struct ProjectParser {
	/// Path to the xcodeproj or xcworkspace bundle
	let path: URL
	/// The type of project
	let type: ProjectType

	/// Mapping of targets (the specification of a build) to products (the result of a build of a target)
	public let targetsToProducts: [String: String]

	enum ProjectType {
		case project(XcodeProject)
		case workspace(XcodeWorkspace)
	}

	public enum Error: Swift.Error {
		case invalidPath(String)
	}

	public init(path: URL, logLevel level: Logger.Level) throws {
		self.path = path
		logger.logLevel = level

		if path.lastPathComponent.hasSuffix("xcodeproj") {
			self.type = .project(try XcodeProject(path: path))
		} else if path.lastPathComponent.hasSuffix("xcworkspace") {
			self.type = .workspace(try XcodeWorkspace(path: path))
		} else {
			throw Error.invalidPath("Path should be a xcodeproj or xcworkspace, got: \(path.lastPathComponent)")
		}

		switch type {
		case .project(let project):
			targetsToProducts = project.targetsAndProducts()
		case .workspace(let workspace):
			targetsToProducts = workspace.targetsAndProducts()
		}
	}

	/// Lists dependencies for a given target
	/// - Parameter target: the target to get dependencies for
	/// - Returns: an array of dependencies
	public func dependencies(for target: String) -> [String] {
		// HACK: Swift packages in pbxproj don't have a way to look up dependencies, so ignore them... for now
		if !target.contains(".") { return [] }

		guard let project = project(for: target) else {
			logger.error("Failed to find project for target: \(target)")
			return []
		}

		guard let target = project.targets[target] else {
			logger.error("Failed to find a target: \(target) in project: \(project.path)")
			return []
		}

		return target.targetDependencies.values
			.compactMap { dependency in
				if case .native(let native) = dependency {
					return project.path(for: native)
				}

				return dependency.name
			}
	}

	/// Gets a project for a given target
	/// - Parameter target: the target to search for
	/// - Returns: a `XcodeProject` that holds the target, if one was found
	private func project(for target: String) -> XcodeProject? {
		switch type {
		case .project(let project): return project
		case .workspace(let workspace): return workspace.targetsToProject[target]
		}
	}
}
