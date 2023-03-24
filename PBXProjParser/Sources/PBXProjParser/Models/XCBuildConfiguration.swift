//
//  XCBuildConfiguration.swift
//
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

class XCBuildConfiguration: PBXObject {
	#if FULL_PBX_PARSING
	var baseConfigurationReference: String?
	var buildSettings: [String: Any]
	var name: String

	private enum CodingKeys: String, CodingKey {
		case baseConfigurationReference
		case buildSettings
		case name
	}
	#endif

	required init(from decoder: Decoder) throws {
		#if FULL_PBX_PARSING
		let container = try decoder.container(keyedBy: CodingKeys.self)

		baseConfigurationReference = try container.decodeIfPresent(String.self, forKey: .baseConfigurationReference)
		buildSettings = try container.decode([String: Any].self, forKey: .buildSettings)
		name = try container.decode(String.self, forKey: .name)
		#endif

		try super.init(from: decoder)
	}
}
