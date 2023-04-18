import Foundation
import Logging

var logger: Logger = .init(label: "com.veracode.PBXProjParser")

public struct ProjectParser {
	/// Path to the xcodeproj or xcworkspace bundle
	let path: URL

	/// The type of project
	let type: ProjectType

	/// Gets all the native targets for the given project
	public var targets: [PBXNativeTarget] {
		switch type {
		case .project(let project):
			return project.targets
		case .workspace(let workspace):
			return workspace.targets
		}
	}

	/// Gets all the packages for the given project
	public var packages: [XCSwiftPackageProductDependency] {
		switch type {
		case .project(let project):
			return project.packages
		case .workspace(let workspace):
			return workspace.packages
		}
	}

	/// Type of project this parser is working on
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

		switch path.pathExtension {
		case "xcodeproj":
			let project = try XcodeProject(path: path)
			type = .project(project)
		case "xcworkspace":
			let workspace = try XcodeWorkspace(path: path)
			type = .workspace(workspace)
		default:
			throw Error.invalidPath("Path should be a xcodeproj or xcworkspace, got: \(path.lastPathComponent)")
		}
	}

	/// Lists dependencies for a given target
	/// - Parameter target: the target to get dependencies for
	/// - Returns: an array of dependencies
	public func dependencies(for target: String) -> [String] {
		guard let project = project(for: target) else {
			logger.error("Failed to find project for target: \(target)")
			return []
		}

		guard let target = project.target(for: target) else {
			// SPMs don't list their dependencies in the pbxproj, skip warning about them
			if project.package(for: target) == nil {
				// TODO: once SPM dependencies work better, move this back to error level warning
				logger.debug(
					"""
					Failed to find a target: \(target) in project: \(project.path). \
					Possible targets: \(project.targets.map { ($0.name, $0.productName ?? "nil")}). \
					Possible Packages: \(project.packages.map { $0.productName} )
					"""
				)
			}

			return []
		}

		return target.targetDependencies
			.values
			.map { dependency in
				if case .native(let native) = dependency, let path = project.path(for: native) {
					return path
				}

				return dependency.name
			}
	}

	/// Gets a project for a given target
	/// - Parameter target: the target to search for
	/// - Returns: a `XcodeProject` that holds the target, if one was found
	private func project(for target: String) -> XcodeProject? {
		switch type {
		case .project(let project):				return project
		case .workspace(let workspace):	return workspace.targetsToProject[target]
		}
	}
}
