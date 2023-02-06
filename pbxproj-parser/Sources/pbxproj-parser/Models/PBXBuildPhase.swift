//
//  PBXBuildPhase.swift
//  
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

class PBXBuildPhase: PBXObject {
	let alwaysOutOfDate: String?
	let buildActionMask: UInt32 /// always UInt32.max
	let files: [String]
	let runOnlyForDeploymentPostprocessing: Int /// always 0

	private enum CodingKeys: String, CodingKey {
		case alwaysOutOfDate
		case buildActionMask
		case files
		case runOnlyForDeploymentPostprocessing
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		alwaysOutOfDate = try container.decodeIfPresent(String.self, forKey: .alwaysOutOfDate)
		let mask = try container.decode(String.self, forKey: .buildActionMask)
		buildActionMask = UInt32(mask) ?? 0
		files = try container.decode([String].self, forKey: .files)
		let flag = try container.decode(String.self, forKey: .runOnlyForDeploymentPostprocessing)
		runOnlyForDeploymentPostprocessing = Int(flag) ?? 0

		try super.init(from: decoder)
	}
}

class PBXFrameworksBuildPhase: PBXBuildPhase {}
class PBXHeadersBuildPhase: PBXBuildPhase {}
class PBXResourcesBuildPhase: PBXBuildPhase {}
class PBXSourcesBuildPhase: PBXBuildPhase {}
class PBXAppleScriptBuildPhase: PBXBuildPhase {}
class PBXRezBuildPhase: PBXBuildPhase {}

class PBXCopyFilesBuildPhase: PBXBuildPhase {
	let dstPath: String
	let dstSubfolderSpec: String

	private enum CodingKeys: String, CodingKey {
		case dstPath
		case dstSubfolderSpec
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		dstPath = try container.decode(String.self, forKey: .dstPath)
		dstSubfolderSpec = try container.decode(String.self, forKey: .dstSubfolderSpec)

		try super.init(from: decoder)
	}
}

class PBXShellScriptBuildPhase: PBXBuildPhase {
	let inputPaths: [String]?
	let outputPaths: [String]?
	let shellPath: String
	let shellScript: String

	private enum CodingKeys: String, CodingKey {
		case inputPaths
		case outputPaths
		case shellPath
		case shellScript
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		inputPaths = try container.decodeIfPresent([String].self, forKey: .inputPaths)
		outputPaths = try container.decodeIfPresent([String].self, forKey: .outputPaths)
		shellPath = try container.decode(String.self, forKey: .shellPath)
		shellScript = try container.decode(String.self, forKey: .shellScript)

		try super.init(from: decoder)
	}
}
