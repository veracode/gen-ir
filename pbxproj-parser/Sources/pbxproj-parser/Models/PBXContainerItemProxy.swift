//
//  PBXContainerItemProxy.swift
//  
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

class PBXContainerItemProxy: PBXObject {
	let containerPortal: String
	let proxyType: String
	let remoteGlobalIDString: String
	let remoteInfo: String

	private enum CodingKeys: String, CodingKey {
		case containerPortal
		case proxyType
		case remoteGlobalIDString
		case remoteInfo
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		containerPortal = try container.decode(String.self, forKey: .containerPortal)
		proxyType = try container.decode(String.self, forKey: .proxyType)
		remoteGlobalIDString = try container.decode(String.self, forKey: .remoteGlobalIDString)
		remoteInfo = try container.decode(String.self, forKey: .remoteInfo)

		try super.init(from: decoder)
	}

	
}
