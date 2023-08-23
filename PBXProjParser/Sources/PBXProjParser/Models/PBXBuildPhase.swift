//
//  PBXBuildPhase.swift
//
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

public class PBXBuildPhase: PBXObject {
	public let files: [String]
#if FULL_PBX_PARSING
	public let alwaysOutOfDate: String?
	public let buildActionMask: UInt32
	public let runOnlyForDeploymentPostprocessing: Int
#endif

	private enum CodingKeys: String, CodingKey {
		case files
		#if FULL_PBX_PARSING
		case alwaysOutOfDate
		case buildActionMask
		case runOnlyForDeploymentPostprocessing
		#endif
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		#if FULL_PBX_PARSING
		alwaysOutOfDate = try container.decodeIfPresent(String.self, forKey: .alwaysOutOfDate)

		let mask = try container.decode(String.self, forKey: .buildActionMask)
		buildActionMask = UInt32(mask) ?? 0

		let flag = try container.decode(String.self, forKey: .runOnlyForDeploymentPostprocessing)
		runOnlyForDeploymentPostprocessing = Int(flag) ?? 0
		#endif

		files = try container.decodeIfPresent([String].self, forKey: .files) ?? []

		try super.init(from: decoder)
	}
}

public class PBXCopyFilesBuildPhase: PBXBuildPhase {
#if FULL_PBX_PARSING
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
#endif
}

public class PBXShellScriptBuildPhase: PBXBuildPhase {
#if FULL_PBX_PARSING
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
#endif
}

public class PBXFrameworksBuildPhase: PBXBuildPhase {}
public class PBXHeadersBuildPhase: PBXBuildPhase {}
public class PBXResourcesBuildPhase: PBXBuildPhase {}
public class PBXSourcesBuildPhase: PBXBuildPhase {}
public class PBXAppleScriptBuildPhase: PBXBuildPhase {}
public class PBXRezBuildPhase: PBXBuildPhase {}
