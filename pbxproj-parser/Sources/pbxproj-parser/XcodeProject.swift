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
	let targets: [PBXNativeTarget]
	private(set) var dependencyGraphs: [String: DependencyGraph] = [:]
	private(set) var embeddedFrameworks: [String] = []

	public init(path: URL) throws {
		self.path = path
		pbxprojPath = path.appendingPathComponent("project.pbxproj")
		model = try pbxproj.contentsOf(pbxprojPath)

		project = model.project()
		targets = model.objects(for: project.targets)

		dependencyGraphs = targets.reduce(into: [String: DependencyGraph](), { partialResult, target in
			partialResult[self.path(for: target)] = .init(target, for: model)
		})

		embeddedFrameworks = model.objects(of: .copyFilesBuildPhase, as: PBXCopyFilesBuildPhase.self)
			.flatMap { $0.files }
			.compactMap { model.object(key: $0, as: PBXBuildFile.self) }
			.map { $0.fileRef }
			.compactMap { model.object(key: $0, as: PBXFileReference.self) }
			.filter { $0.explicitFileType == "wrapper.framework" || $0.path.hasSuffix(".framework") }
			.map { $0.path }
	}

	func targetsAndProducts() -> [String: String] {
		targets.reduce(into: [String: String]()) { partialResult, target in
			partialResult[target.name] = path(for: target)
		}
	}

	func object<T>(for reference: String, as type: T.Type) -> T? {
		model.object(key: reference, as: T.self)
	}

	func path(for target: PBXNativeTarget) -> String {
		guard let reference = object(for: target.productReference, as: PBXFileReference.self) else {
			fatalError("Fix this later")
		}

		return reference.path
	}
}
