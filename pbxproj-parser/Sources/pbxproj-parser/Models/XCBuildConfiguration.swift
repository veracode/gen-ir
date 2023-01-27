//
//  XCBuildConfiguration.swift
//  
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

class XCBuildConfiguration: PBXObject {
	var baseConfigurationReference: String?
	var buildSettings: BuildSettings
	var name: String

	private enum CodingKeys: String, CodingKey {
		case baseConfigurationReference
		case buildSettings
		case name
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		baseConfigurationReference = try container.decodeIfPresent(String.self, forKey: .baseConfigurationReference)
		buildSettings = try container.decode(BuildSettings.self, forKey: .buildSettings)
		name = try container.decode(String.self, forKey: .name)

		try super.init(from: decoder)
	}
}
