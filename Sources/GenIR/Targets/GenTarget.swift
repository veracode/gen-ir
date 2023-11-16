//
//  GenTarget.swift
//
//
//  Created by Kevin Rise on 23/10/2023.
//

// TODO: this should probably get merged with the Target class

import Foundation

public struct GenTarget {
	//let buildTarget: BuildTarget
	var guid: String
	var filename: URL
	var name: String
	var type: TargetType
	var isDependency: Bool
	// var Dependencies[] 

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

	public init(guid: String, filename: URL, name: String, typeName: String) {
		self.guid = guid
		self.filename = filename
		self.name = name
		self.type = Self.getType(typeName: typeName)
		self.isDependency = false
	}

	private static func getType(typeName: String) -> TargetType {
		switch typeName {
			case "wrapper.application":
				return TargetType.Application
			case "wrapper.framework":
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