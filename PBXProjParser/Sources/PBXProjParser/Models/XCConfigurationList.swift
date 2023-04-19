//
//  XCConfigurationList.swift
//
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

public class XCConfigurationList: PBXObject {
	public let buildConfigurations: [String]
	#if FULL_PBX_PARSING
	public let defaultConfigurationIsVisible: String
	public let defaultConfigurationName: String
	#endif

	private enum CodingKeys: String, CodingKey {
		case buildConfigurations
		#if FULL_PBX_PARSING
		case defaultConfigurationIsVisible
		case defaultConfigurationName
		#endif
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		buildConfigurations = try container.decodeIfPresent([String].self, forKey: .buildConfigurations) ?? []
		#if FULL_PBX_PARSING
		defaultConfigurationIsVisible = try container.decode(String.self, forKey: .defaultConfigurationIsVisible)
		defaultConfigurationName = try container.decode(String.self, forKey: .defaultConfigurationName)
		#endif

		try super.init(from: decoder)
	}
}
