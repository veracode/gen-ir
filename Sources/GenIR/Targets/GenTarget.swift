//
//  GenTarget.swift
//
//
//  Created by Kevin Rise on 23/10/2023.
//

// TODO: this should probably get merged with the Target class

import Foundation

public class GenTarget {
	//let buildTarget: BuildTarget
	var guid: String
	var file: URL
	var name: String
	var type: TargetType
	var isDependency: Bool
	// var Dependencies[] 

	// A list of CompilerCommands relating to this target
	var commands: [CompilerCommand] = []

	public enum TargetType: CustomStringConvertible {
		case Application
		case Framework
		case Bundle
		case Extension
		case Package
		case Unknown

		public var description: String {
			switch self {
				case .Application: return "Application"
				case .Framework: return "Framework"
				case .Bundle: return "Bundle"
				case .Extension: return "Extension"
				case .Package: return "Package"
				default: return "Unknown"
			}
		}
	}

	public init(guid: String, file: URL, name: String, typeName: String) {
		self.guid = guid
		self.file = file
		self.name = name
		self.type = Self.getType(typeName: typeName)
		self.isDependency = false
	}

	private static func getType(typeName: String) -> TargetType {
		switch typeName {
			case "com.apple.product-type.application":
				return TargetType.Application
			case "com.apple.product-type.framework":
				return TargetType.Framework
			case "wrapper.cfbundle":
				return TargetType.Bundle
			case "wrapper.app-extension":
				return TargetType.Extension
			case "packageProduct":
				return TargetType.Package
			default:
				return TargetType.Unknown
		}
	}

}