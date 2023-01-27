//
//  XcodeProject.swift
//  
//
//  Created by Thomas Hedderwick on 27/01/2023.
//

import Foundation

enum ParsingError: Error {
	case missingKey(String)
	case validationError(String)
}

public struct XcodeProject {
	/// Path to the Project or Workspace
	public let path: URL
	private let pbxprojPath: URL
	private let model: pbxproj

	let project: PBXProject
	let targets: [PBXTarget]

	/// Mapping of target UUID to target name
//	let targets: [PBXTarget]

	enum Error: Swift.Error {
		case parsingFailure(String)
	}

	public init(path: URL) throws {
		self.path = path
		pbxprojPath = path.appendingPathComponent("project.pbxproj")
		model = try pbxproj.contentsOf(pbxprojPath)

		project = model.project()
		targets = model.objects(for: project.targets).compactMap { $0 as? PBXTarget }

		print(targets)



//		targets = try Self.targets(from: model)
//		print(targets)
	}

//	private static func targets(from model: pbxproj) throws -> [PBXTarget] {
//		guard let project = model.project() else {
//			throw Error.parsingFailure("Failed to get projects from pbxproj")
//		}
//
//		let targets = project.targets
//
//		return targets.compactMap { model.objects[$0] as? PBXTarget }
//	}
}
