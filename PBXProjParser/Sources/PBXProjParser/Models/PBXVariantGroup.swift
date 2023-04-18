//
//  PBXVariantGroup.swift
//
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

public class PBXVariantGroup: PBXObject {
	#if FULL_PBX_PARSING
	let children: [String]
	let name: String
	let sourceTree: String

	private enum CodingKeys: String, CodingKey {
		case children
		case name
		case sourceTree
	}
	#endif

	required init(from decoder: Decoder) throws {
		#if FULL_PBX_PARSING
		let container = try decoder.container(keyedBy: CodingKeys.self)

		children = try container.decode([String].self, forKey: .children)
		name = try container.decode(String.self, forKey: .name)
		sourceTree = try container.decode(String.self, forKey: .sourceTree)
		#endif

		try super.init(from: decoder)
	}
}
