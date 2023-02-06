import Foundation

public struct ProjectParser {
	let path: URL
	let type: ProjectType

	let project: XcodeProject?
	let workspace: XcodeWorkspace?

	public let targetsToProducts: [String: String]

	enum ProjectType {
		case project
		case workspace
	}

	public init(path: URL) throws {
		self.path = path
		self.type = path.lastPathComponent.hasSuffix("xcodeproj") ? .project : .workspace

		switch type {
		case .project:
			project = try XcodeProject(path: path)
			workspace = nil
			targetsToProducts = project!.targetsAndProducts()
		case .workspace:
			// For workspaces, we need to parse the XML file: contents.xcworkspacedata for xcodeprojects and load them up
			project = nil
			workspace = try XcodeWorkspace(path: path)
			targetsToProducts = workspace!.targetsAndProducts()
		}
	}
}
