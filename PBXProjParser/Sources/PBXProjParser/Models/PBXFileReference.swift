//
//  PBXFileReference.swift
//  
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

class PBXFileReference: PBXObject {
	#if DEBUG
	let fileEncoding: String?
	let explicitFileType: String?
	let includeInIndex: String?
	let lastKnownFileType: String?
	let name: String?
	let sourceTree: String
	#endif
	let path: String

	private enum CodingKeys: String, CodingKey {
		#if DEBUG
		case fileEncoding
		case explicitFileType
		case includeInIndex
		case lastKnownFileType
		case name
		case sourceTree
		#endif
		case path
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		#if DEBUG
		fileEncoding = try container.decodeIfPresent(String.self, forKey: .fileEncoding)
		explicitFileType = try container.decodeIfPresent(String.self, forKey: .explicitFileType)
		includeInIndex = try container.decodeIfPresent(String.self, forKey: .includeInIndex)
		lastKnownFileType = try container.decodeIfPresent(String.self, forKey: .lastKnownFileType)
		name = try container.decodeIfPresent(String.self, forKey: .name)
		sourceTree = try container.decode(String.self, forKey: .sourceTree)
		#endif
		path = try container.decode(String.self, forKey: .path)

		try super.init(from: decoder)
	}
}

class PBXReferenceProxy: PBXObject {}
