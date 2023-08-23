//
//  PBXTarget.swift
//
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

public class PBXTarget: PBXObject {
	#if FULL_PBX_PARSING
	public let buildConfigurationList: String
	public let comments: String?
	#endif
	public let productName: String?
	public let name: String
	public let dependencies: [String]

	private enum CodingKeys: String, CodingKey {
		#if FULL_PBX_PARSING
		case buildConfigurationList
		case comments
		#endif
		case productName
		case name
		case dependencies

	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		#if FULL_PBX_PARSING
		buildConfigurationList = try container.decode(String.self, forKey: .buildConfigurationList)
		comments = try container.decodeIfPresent(String.self, forKey: .comments)
		#endif
		productName = try container.decodeIfPresent(String.self, forKey: .productName)
		name = try container.decode(String.self, forKey: .name)
		dependencies = try container.decode([String].self, forKey: .dependencies)

		try super.init(from: decoder)
	}
}

public class PBXAggregateTarget: PBXTarget {
	public let buildPhases: [String]

	private enum CodingKeys: String, CodingKey {
		case buildPhases
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		buildPhases = try container.decode([String].self, forKey: .buildPhases)

		try super.init(from: decoder)
	}
}

public class PBXLegacyTarget: PBXTarget {}

public class PBXNativeTarget: PBXTarget {
	#if FULL_PBX_PARSING
	public let productInstallPath: String?
	#endif
	public let buildPhases: [String]
	public let productType: String?
	public let productReference: String?
	public let packageProductDependencies: [String]

	private(set) var targetDependencies: [String: TargetDependency] = [:]

	public enum TargetDependency {
		case native(PBXNativeTarget)
		case package(XCSwiftPackageProductDependency)
		case externalProjectFramework(String)

		public var name: String {
			switch self {
			case .native(let target):
				return target.name
			case .package(let package):
				return package.productName
			case .externalProjectFramework(let filename):
				return (filename as NSString).deletingPathExtension
			}
		}
	}

	private enum CodingKeys: String, CodingKey {
		#if FULL_PBX_PARSING
		case productInstallPath
		#endif
		case buildPhases
		case productType
		case productReference
		case packageProductDependencies
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		#if FULL_PBX_PARSING
		productInstallPath = try container.decodeIfPresent(String.self, forKey: .productInstallPath)
		#endif
		buildPhases = try container.decodeIfPresent([String].self, forKey: .buildPhases) ?? []
		productType = try container.decodeIfPresent(String.self, forKey: .productType)
		productReference = try container.decodeIfPresent(String.self, forKey: .productReference)
		packageProductDependencies = try container.decodeIfPresent([String].self, forKey: .packageProductDependencies) ?? []

		try super.init(from: decoder)
	}

	func add(dependency: TargetDependency) {
		targetDependencies[dependency.name] = dependency
	}
}

extension PBXNativeTarget: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(isa)
		hasher.combine(reference)
		hasher.combine(productName)
		hasher.combine(name)
	}
}

extension PBXNativeTarget: Equatable {
	public static func == (lhs: PBXNativeTarget, rhs: PBXNativeTarget) -> Bool {
		// This should be enough as references _should_ be unique to the object
		lhs.reference == rhs.reference
	}
}

extension PBXNativeTarget: CustomStringConvertible {
	public var description: String {
		#if FULL_PBX_PARSING
		"""
		<PBXNativeTarget -- BuildPhases: \(buildPhases), productInstallPath: \(productInstallPath ?? "nil") \
		productReference: \(productReference ?? "nil"), productType: \(productType ?? "nil"), \
		packageProductDependencies: \(packageProductDependencies)>
		"""
		#else
		"""
		<PBXNativeTarget --  name: \(name), productName: \(productName ?? "nil"), productType: \(productType ?? "nil"), \
		productReference: \(productReference ?? "nil"), packageProductDependencies: \(packageProductDependencies)>
		"""
		#endif
	}
}

public class PBXTargetDependency: PBXObject {
	public let target: String?
	public let targetProxy: String?

	private enum CodingKeys: String, CodingKey {
		case target
		case targetProxy
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		target = try container.decodeIfPresent(String.self, forKey: .target)
		targetProxy = try container.decodeIfPresent(String.self, forKey: .targetProxy)

		try super.init(from: decoder)
	}
}
