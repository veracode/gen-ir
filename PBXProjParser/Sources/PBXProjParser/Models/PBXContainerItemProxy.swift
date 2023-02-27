//
//  PBXContainerItemProxy.swift
//  
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

class PBXContainerItemProxy: PBXObject {
	#if DEBUG
	let containerPortal: String
	let proxyType: String
	let remoteInfo: String
	#endif
	let remoteGlobalIDString: String

	private enum CodingKeys: String, CodingKey {
		#if DEBUG
		case containerPortal
		case proxyType
		case remoteInfo
		#endif
		case remoteGlobalIDString

	}


	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		#if DEBUG
		containerPortal = try container.decode(String.self, forKey: .containerPortal)
		proxyType = try container.decode(String.self, forKey: .proxyType)
		remoteInfo = try container.decode(String.self, forKey: .remoteInfo)
		#endif

		remoteGlobalIDString = try container.decode(String.self, forKey: .remoteGlobalIDString)

		try super.init(from: decoder)
	}
}
