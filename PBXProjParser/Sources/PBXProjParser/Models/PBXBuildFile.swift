//
//  PBXBuildFile.swift
//  
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

class PBXBuildFile: PBXObject {
#if DEBUG
	let fileRef: String?
	let platformFilter: String?
	let platformFilters: [String]?
	let productRef: String?
	let settings: [String: Any]?

	private enum CodingKeys: String, CodingKey {
		case fileRef
		case platformFilter
		case platformFilters
		case productRef
		case settings
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		fileRef = try container.decodeIfPresent(String.self, forKey: .fileRef)
		platformFilter = try container.decodeIfPresent(String.self, forKey: .platformFilter)
		platformFilters = try container.decodeIfPresent([String].self, forKey: .platformFilters)
		productRef = try container.decodeIfPresent(String.self, forKey: .productRef)
		settings = try container.decodeIfPresent([String: Any].self, forKey: .settings)

		try super.init(from: decoder)
	}
#endif
}

class PBXBuildRule: PBXObject {}
