//
//  BuildTarget.swift
//
//
//  Created by Kevin Rise on 10/11/23
//

import Foundation

// TODO: ?? move to genIR?


// TODO: this enum is shared by both this and the TARGET file parser - combine/do-better
public enum TargetType: CustomStringConvertible {
		case Application
		case Framework
		case Bundle
		case Extension
		case Unknown

		public var description: String {
			switch self {
				case .Application: return "Application"
				case .Framework: return "Framework"
				case .Bundle: return "Bundle"
				case .Extension: return "Extension"
				default: return "Unknown"
			}
		}
	}

/// Represents a build target we need to process
public struct BuildTarget {

	public let name: String
	let productName: String
	let frPath: String
	public let type: TargetType

	public init(name: String, productName: String, fileRef: PBXFileReference) {
		self.name = name
		self.productName = productName
		self.frPath = fileRef.path
		self.type = Self.getType(typeName: fileRef.explicitFileType)

	}

	// public var description: String {
	//     return "{name: \(name), productName: \(productName), type: \(type), fileRefPath: \(frPath)}"
	// }
	
	private static func getType(typeName: String?) -> TargetType{
		switch typeName {
			case "wrapper.application":
				return TargetType.Application
			case "wrapper.framework":
				return TargetType.Framework
			case "wrapper.cfbundle":
				return TargetType.Bundle
			case "wrapper.app-extension":
				return TargetType.Extension
			default:
				return TargetType.Unknown
		}
	}


}