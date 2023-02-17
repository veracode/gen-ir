//
//  PBXFileReference.swift
//  
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

class PBXFileReference: PBXObject {
	let fileEncoding: String?
	let explicitFileType: String?
	let includeInIndex: String?
	let lastKnownFileType: String?
	let name: String?
	let path: String
	let sourceTree: String

	private enum CodingKeys: String, CodingKey {
		case fileEncoding
		case explicitFileType
		case includeInIndex
		case lastKnownFileType
		case name
		case path
		case sourceTree
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		fileEncoding = try container.decodeIfPresent(String.self, forKey: .fileEncoding)
		explicitFileType = try container.decodeIfPresent(String.self, forKey: .explicitFileType)
		includeInIndex = try container.decodeIfPresent(String.self, forKey: .includeInIndex)
		lastKnownFileType = try container.decodeIfPresent(String.self, forKey: .lastKnownFileType)
		name = try container.decodeIfPresent(String.self, forKey: .name)
		path = try container.decode(String.self, forKey: .path)
		sourceTree = try container.decode(String.self, forKey: .sourceTree)

		try super.init(from: decoder)
	}
}

class PBXReferenceProxy: PBXObject {}
