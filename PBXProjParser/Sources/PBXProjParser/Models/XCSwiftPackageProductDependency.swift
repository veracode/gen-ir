//
//  XCSwiftPackageProductDependency.swift
//  
//
//  Created by Thomas Hedderwick on 15/02/2023.
//

import Foundation

class XCSwiftPackageProductDependency: PBXObject {
	let package: String?
	let productName: String

	private enum CodingKeys: CodingKey {
		case package
		case productName
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		package = try container.decodeIfPresent(String.self, forKey: .package)
		productName = try container.decode(String.self, forKey: .productName)

		try super.init(from: decoder)
	}
}

class XCRemoteSwiftPackageReference: PBXObject {}
class XCVersionGroup: PBXObject {}
