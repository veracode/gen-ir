//
//  XCConfigurationList.swift
//  
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

class XCConfigurationList: PBXObject {
	let buildConfigurations: [String]
	let defaultConfigurationIsVisible: String
	let defaultConfigurationName: String

	private enum CodingKeys: String, CodingKey {
		case buildConfigurations
		case defaultConfigurationIsVisible
		case defaultConfigurationName
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		buildConfigurations = try container.decode([String].self, forKey: .buildConfigurations)
		defaultConfigurationIsVisible = try container.decode(String.self, forKey: .defaultConfigurationIsVisible)
		defaultConfigurationName = try container.decode(String.self, forKey: .defaultConfigurationName)

		try super.init(from: decoder)
	}
}
