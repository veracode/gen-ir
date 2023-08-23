//
//  PBXBuildFile.swift
//
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

public class PBXBuildFile: PBXObject {
	public let productRef: String?
	public let fileRef: String?

	#if FULL_PBX_PARSING
	public let platformFilter: String?
	public let platformFilters: [String]?
	public let settings: [String: Any]?
	#endif

	private enum CodingKeys: String, CodingKey {
		case productRef
		case fileRef

		#if FULL_PBX_PARSING
		case platformFilter
		case platformFilters
		case settings
		#endif
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		productRef = try container.decodeIfPresent(String.self, forKey: .productRef)
		fileRef = try container.decodeIfPresent(String.self, forKey: .fileRef)

		#if FULL_PBX_PARSING
		platformFilter = try container.decodeIfPresent(String.self, forKey: .platformFilter)
		platformFilters = try container.decodeIfPresent([String].self, forKey: .platformFilters)
		settings = try container.decodeIfPresent([String: Any].self, forKey: .settings)
		#endif

		try super.init(from: decoder)
	}
}

public class PBXBuildRule: PBXObject {}
