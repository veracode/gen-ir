//
//  PBXProject.swift
//
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

public class PBXProject: PBXObject {
	#if FULL_PBX_PARSING
	public let attributes: [String: Any]
	public let buildConfigurationList: String
	public let compatibilityVersion: String
	public let developmentRegion: String
	public let hasScannedForEncodings: String
	public let knownRegions: [String]
	public let mainGroup: String
	public let productRefGroup: String
	public let projectDirPath: String
	public let projectReferences: [[String: String]]?
	public let projectRoot: String
	#endif
	public let packageReferences: [String]
	public let targets: [String] /// Hold references to targets via their identifiers

	private enum CodingKeys: String, CodingKey {
		case attributes
		case buildConfigurationList
		case compatibilityVersion
		case developmentRegion
		case hasScannedForEncodings
		case knownRegions
		case mainGroup
		case productRefGroup
		case projectDirPath
		case projectReferences
		case packageReferences
		case projectRoot
		case targets
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
#if FULL_PBX_PARSING
		// We currently don't decode this as it's painful and we don't need it
		attributes = [:]
		buildConfigurationList = try container.decode(String.self, forKey: .buildConfigurationList)
		compatibilityVersion = try container.decode(String.self, forKey: .compatibilityVersion)
		developmentRegion = try container.decode(String.self, forKey: .developmentRegion)
		hasScannedForEncodings = try container.decode(String.self, forKey: .hasScannedForEncodings)
		knownRegions = try container.decode([String].self, forKey: .knownRegions)
		mainGroup = try container.decode(String.self, forKey: .mainGroup)
		productRefGroup = try container.decode(String.self, forKey: .productRefGroup)
		projectDirPath = try container.decode(String.self, forKey: .projectDirPath)
		projectReferences = try container.decodeIfPresent([[String: String]].self, forKey: .projectReferences)
		projectRoot = try container.decode(String.self, forKey: .projectRoot)
#endif
		packageReferences = try container.decodeIfPresent([String].self, forKey: .packageReferences) ?? []
		targets = try container.decode([String].self, forKey: .targets)

		try super.init(from: decoder)
	}
}
