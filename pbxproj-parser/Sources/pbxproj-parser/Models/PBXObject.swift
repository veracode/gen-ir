//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 31/01/2023.
//

import Foundation

/// Base class for all objects
class PBXObject: Decodable {
	/// Objects class name
	let isa: PBXObjectType
	var reference: String!
}

/// Single case enum that decodes and holds a reference to an underlying `PBXObject` subclass
enum Object: Decodable {
	/// The wrapped object
	case object(PBXObject)

	private enum CodingKeys: String, CodingKey {
		case isa
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let isa = try container.decode(PBXObjectType.self, forKey: .isa)
		let singleContainer = try decoder.singleValueContainer()

		self = .object(try singleContainer.decode(isa.getType()))
	}

	func unwrap() -> PBXObject {
		if case .object(let object) = self {
			return object
		}

		fatalError("Failed to unwrap the underlying PBXObject, this should only happen if someone adds a case to `Object` and didn't handle it.")
	}
}

enum PBXObjectType: String, Decodable, CaseIterable {
	case buildFile = "PBXBuildFile"
	case appleScriptBuildPhase = "PBXAppleScriptBuildPhase"
	case copyFilesBuildPhase = "PBXCopyFilesBuildPhase"
	case frameworksBuildPhase = "PBXFrameworksBuildPhase"
	case headersBuildPhase = "PBXHeadersBuildPhase"
	case resourcesBuildPhase = "PBXResourcesBuildPhase"
	case shellScriptBuildPhase = "PBXShellScriptBuildPhase"
	case sourcesBuildPhase = "PBXSourcesBuildPhase"
	case containerItemProxy = "PBXContainerItemProxy"
	case fileReference = "PBXFileReference"
	case group = "PBXGroup"
	case variantGroup = "PBXVariantGroup"
	case aggregateTarget = "PBXAggregateTarget"
	case legacyTarget = "PBXLegacyTarget"
	case nativeTarget = "PBXNativeTarget"
	case project = "PBXProject"
	case targetDependency = "PBXTargetDependency"
	case buildConfiguration = "XCBuildConfiguration"
	case configurationList = "XCConfigurationList"
	case swiftPackageProductDependecy = "XCSwiftPackageProductDependency"
	case remoteSwiftPackageReference = "XCRemoteSwiftPackageReference"
	case referenceProxy = "PBXReferenceProxy"
	case versionGroup = "XCVersionGroup"

	// swiftlint:disable cyclomatic_complexity
	func getType() -> PBXObject.Type {
		switch self {
		case .buildFile:						return PBXBuildFile.self
		case .appleScriptBuildPhase:				return PBXAppleScriptBuildPhase.self
		case .copyFilesBuildPhase:					return PBXCopyFilesBuildPhase.self
		case .frameworksBuildPhase:					return PBXFrameworksBuildPhase.self
		case .headersBuildPhase:						return PBXHeadersBuildPhase.self
		case .resourcesBuildPhase:					return PBXResourcesBuildPhase.self
		case .shellScriptBuildPhase:				return PBXShellScriptBuildPhase.self
		case .sourcesBuildPhase:						return PBXSourcesBuildPhase.self
		case .containerItemProxy:						return PBXContainerItemProxy.self
		case .fileReference:								return PBXFileReference.self
		case .group:												return PBXGroup.self
		case .variantGroup:									return PBXVariantGroup.self
		case .aggregateTarget:							return PBXAggregateTarget.self
		case .legacyTarget:									return PBXLegacyTarget.self
		case .nativeTarget:									return PBXNativeTarget.self
		case .project:											return PBXProject.self
		case .targetDependency:							return PBXTargetDependency.self
		case .buildConfiguration:						return XCBuildConfiguration.self
		case .configurationList:						return XCConfigurationList.self
		case .swiftPackageProductDependecy:	return XCSwiftPackageProductDependency.self
		case .remoteSwiftPackageReference:	return XCRemoteSwiftPackageReference.self
		case .referenceProxy:								return PBXReferenceProxy.self
		case .versionGroup:									return XCVersionGroup.self
		}
	}
}
