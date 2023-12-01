//
//  PBXFileReference.swift
//
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

public class PBXFileReference: PBXObject {
	#if FULL_PBX_PARSING
	public let fileEncoding: String?
	public let includeInIndex: String?
	public let lastKnownFileType: String?
	public let name: String?
	public let sourceTree: String
	#endif
	public let explicitFileType: String?
	public let path: String

	private enum CodingKeys: String, CodingKey {
		#if FULL_PBX_PARSING
		case fileEncoding
		case includeInIndex
		case lastKnownFileType
		case name
		case sourceTree
		#endif
		case explicitFileType
		case path
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		explicitFileType = try container.decodeIfPresent(String.self, forKey: .explicitFileType)
		path = try container.decode(String.self, forKey: .path)

		#if FULL_PBX_PARSING
		fileEncoding = try container.decodeIfPresent(String.self, forKey: .fileEncoding)
		includeInIndex = try container.decodeIfPresent(String.self, forKey: .includeInIndex)
		lastKnownFileType = try container.decodeIfPresent(String.self, forKey: .lastKnownFileType)
		name = try container.decodeIfPresent(String.self, forKey: .name)
		sourceTree = try container.decode(String.self, forKey: .sourceTree)
		#endif

		try super.init(from: decoder)
	}
}

public class PBXReferenceProxy: PBXObject {}
