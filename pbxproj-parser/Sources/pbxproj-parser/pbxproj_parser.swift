import Foundation

public struct ProjectParser {
	let path: URL
	let type: ProjectType

	let project: XcodeProject?
	let workspace: XcodeWorkspace?

	enum ProjectType {
		case project
		case workspace

		init(path: URL) {
			self = path.lastPathComponent.hasSuffix("xcodeproj") ? .project : .workspace
		}
	}

	public init(path: URL) throws {
		self.path = path
		self.type = ProjectType(path: path)

		switch type {
		case .project:
			project = try XcodeProject(path: path)
			workspace = nil
			break
		case .workspace:
			// For workspaces, we need to parse the XML file: contents.xcworkspacedata for xcodeprojects and load them up
			project = nil
			workspace = nil
			fatalError("Not yet supported")
			break
		}
	}
}
