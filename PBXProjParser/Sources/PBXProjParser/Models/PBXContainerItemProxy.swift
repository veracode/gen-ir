//
//  PBXContainerItemProxy.swift
//
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

public class PBXContainerItemProxy: PBXObject {
	#if FULL_PBX_PARSING
	public let containerPortal: String
	public let proxyType: String
	public let remoteInfo: String
	#endif
	public let remoteGlobalIDString: String

	private enum CodingKeys: String, CodingKey {
		#if FULL_PBX_PARSING
		case containerPortal
		case proxyType
		case remoteInfo
		#endif
		case remoteGlobalIDString

	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		#if FULL_PBX_PARSING
		containerPortal = try container.decode(String.self, forKey: .containerPortal)
		proxyType = try container.decode(String.self, forKey: .proxyType)
		remoteInfo = try container.decode(String.self, forKey: .remoteInfo)
		#endif

		remoteGlobalIDString = try container.decode(String.self, forKey: .remoteGlobalIDString)

		try super.init(from: decoder)
	}
}
