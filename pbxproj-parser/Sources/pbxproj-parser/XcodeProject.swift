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
	/// Path to the Workspace
	public let path: URL
	private let pbxprojPath: URL
	private let model: pbxproj

	let project: PBXProject
	let targets: [PBXTarget]
	var dependencyGraphs: [String: DependencyGraph] = [:]

	public init(path: URL) throws {
		self.path = path
		pbxprojPath = path.appendingPathComponent("project.pbxproj")
		model = try pbxproj.contentsOf(pbxprojPath)

		project = model.project()
		targets = model.objects(for: project.targets).compactMap { $0 as? PBXTarget }

		dependencyGraphs = targets.reduce(into: [String: DependencyGraph](), { partialResult, target in
			partialResult[target.nameOfProduct()] = .init(target, for: model)
		})
	}

	func targetsAndProducts() -> [String: String] {
		targets.reduce(into: [String: String]()) { partialResult, target in
			partialResult[target.name] = target.nameOfProduct()
		}
	}
}
