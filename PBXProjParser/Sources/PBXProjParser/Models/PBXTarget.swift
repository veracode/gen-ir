//
//  PBXTarget.swift
//  
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

class PBXTarget: PBXObject {
	let buildConfigurationList: String
	let comments: String?
	let name: String
	let productName: String?
	let dependencies: [String]

	private enum CodingKeys: String, CodingKey {
		case buildConfigurationList
		case comments
		case name
		case productName
		case dependencies
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		buildConfigurationList = try container.decode(String.self, forKey: .buildConfigurationList)
		comments = try container.decodeIfPresent(String.self, forKey: .comments)
		name = try container.decode(String.self, forKey: .name)
		productName = try container.decodeIfPresent(String.self, forKey: .productName)
		dependencies = try container.decode([String].self, forKey: .dependencies)

		try super.init(from: decoder)
	}
}

class PBXAggregateTarget: PBXTarget {
	let buildPhases: [String]

	private enum CodingKeys: String, CodingKey {
		case buildPhases
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		buildPhases = try container.decode([String].self, forKey: .buildPhases)

		try super.init(from: decoder)
	}
}

class PBXLegacyTarget: PBXTarget {}

class PBXNativeTarget: PBXTarget {
	let buildPhases: [String]
	let productInstallPath: String?
	let productReference: String
	let productType: String
	let packageProductDependencies: [String]

	private(set) var targetDependencies: [String: TargetDependency] = [:]

	enum TargetDependency {
		case native(PBXNativeTarget)
		case package(XCSwiftPackageProductDependency)

		var name: String {
			switch self {
			case .native(let target):
				return target.name
			case .package(let package):
				return package.productName
			}
		}
	}

	private enum CodingKeys: String, CodingKey {
		case buildPhases
		case productInstallPath
		case productReference
		case productType
		case packageProductDependencies
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		buildPhases = try container.decode([String].self, forKey: .buildPhases)
		productInstallPath = try container.decodeIfPresent(String.self, forKey: .productInstallPath)
		productReference = try container.decode(String.self, forKey: .productReference)
		productType = try container.decode(String.self, forKey: .productType)
		packageProductDependencies = try container.decodeIfPresent([String].self, forKey: .packageProductDependencies) ?? []

		try super.init(from: decoder)
	}

	func add(dependency: TargetDependency) {
		targetDependencies[dependency.name] = dependency
	}
}

extension PBXNativeTarget: CustomStringConvertible {
	var description: String {
		"""
		<PBXNativeTarget: BuildPhases: \(buildPhases), productInstallPath: \(productInstallPath ?? "nil") \
		productReference: \(productReference), productType: \(productType), \
		packageProductDependencies: \(packageProductDependencies)>
		"""
	}
}

class PBXTargetDependency: PBXObject {
	let target: String
	let targetProxy: String

	private enum CodingKeys: String, CodingKey {
		case target
		case targetProxy
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		target = try container.decode(String.self, forKey: .target)
		targetProxy = try container.decode(String.self, forKey: .targetProxy)

		try super.init(from: decoder)
	}
}
