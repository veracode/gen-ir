//
//  XCSwiftPackageProductDependency.swift
//
//
//  Created by Thomas Hedderwick on 15/02/2023.
//

import Foundation

public class XCSwiftPackageProductDependency: PBXObject {
	public let package: String?
	public let productName: String

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

extension XCSwiftPackageProductDependency: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(isa)
		hasher.combine(reference)
		hasher.combine(package)
		hasher.combine(productName)
	}
}

extension XCSwiftPackageProductDependency: Equatable {
	public static func == (lhs: XCSwiftPackageProductDependency, rhs: XCSwiftPackageProductDependency) -> Bool {
		lhs.reference == rhs.reference &&
		lhs.package == rhs.package &&
		lhs.productName == rhs.productName
	}
}

public class XCRemoteSwiftPackageReference: PBXObject {}
public class XCLocalSwiftPackageReference: PBXObject {}
public class XCVersionGroup: PBXObject {}
