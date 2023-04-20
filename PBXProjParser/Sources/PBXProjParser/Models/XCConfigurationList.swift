//
//  XCConfigurationList.swift
//
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

public class XCConfigurationList: PBXObject {
	#if FULL_PBX_PARSING
	public let buildConfigurations: [String]
	public let defaultConfigurationIsVisible: String
	public let defaultConfigurationName: String

	private enum CodingKeys: String, CodingKey {
		case buildConfigurations
		case defaultConfigurationIsVisible
		case defaultConfigurationName
	}
	#endif

	required init(from decoder: Decoder) throws {
		#if FULL_PBX_PARSING
		let container = try decoder.container(keyedBy: CodingKeys.self)

		buildConfigurations = try container.decode([String].self, forKey: .buildConfigurations)
		defaultConfigurationIsVisible = try container.decode(String.self, forKey: .defaultConfigurationIsVisible)
		defaultConfigurationName = try container.decode(String.self, forKey: .defaultConfigurationName)
		#endif

		try super.init(from: decoder)
	}
}
