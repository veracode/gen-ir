//
//  XCBuildConfiguration.swift
//
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

public class XCBuildConfiguration: PBXObject {
	public let baseConfigurationReference: String?
	public var name: String

	#if FULL_PBX_PARSING
	public var buildSettings: [String: Any]
	#endif

	private enum CodingKeys: String, CodingKey {
		case baseConfigurationReference
		case name

		#if FULL_PBX_PARSING
		case buildSettings
		#endif
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		baseConfigurationReference = try container.decodeIfPresent(String.self, forKey: .baseConfigurationReference)
		name = try container.decode(String.self, forKey: .name)
		#if FULL_PBX_PARSING
		buildSettings = try container.decode([String: Any].self, forKey: .buildSettings)
		#endif

		try super.init(from: decoder)
	}
}
