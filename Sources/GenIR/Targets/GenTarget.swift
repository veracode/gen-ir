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
	var dependencyNames: [String]?		// guid of the dependent/child target(s) 
	var dependencyTargets: [GenTarget]?

	// A list of CompilerCommands relating to this target
	var commands: [CompilerCommand] = []

	//var productReference: ProductReference?
	var prodRefName: String?

	// The name to use when writing IR to disk, prefer the product name if possible.
	//lazy var nameForOutput: String = name + "." + self.getPathExtension()
	lazy var nameForOutput: String = prodRefName ?? name + "." + self.getPathExtension()

	public enum TargetType: CustomStringConvertible {
		case Application
		case Framework
		case Bundle
		case Extension
		case Package
		case ObjFile
		case Unknown

		public var description: String {
			switch self {
				case .Application: return "Application"
				case .Framework: return "Framework"
				case .Bundle: return "Bundle"
				case .Extension: return "Extension"
				case .Package: return "Package"
				case .ObjFile: return "ObjectFile"
				default: return "Unknown"
			}
		}
	}

	public init(guid: String, file: URL, name: String, typeName: String, prodRefName: String?, dependencyNames: [String]?) {
		self.guid = guid
		self.file = file
		self.name = name
		self.type = Self.getType(typeName: typeName)
		self.prodRefName = prodRefName
		self.isDependency = false
		self.dependencyNames = dependencyNames
	}

	// public func addDependency(dependency: String) {

	// }

	private static func getType(typeName: String) -> TargetType {
		switch typeName {
			case "com.apple.product-type.application":
				return TargetType.Application
			case "com.apple.product-type.framework":
				return TargetType.Framework
			case "wrapper.cfbundle":							// TODO: fix
				return TargetType.Bundle
			case "wrapper.app-extension":						// TODO: fix
				return TargetType.Extension
			case "packageProduct":								
				return TargetType.Package
			case "com.apple.product-type.objfile":
				return TargetType.ObjFile
			default:
				return TargetType.Unknown
		}
	}

	private func getPathExtension() -> String {
		switch type {
			case .Application: return "app"
			case .Framework: return "framework"
			case .Package: return "package"													
			case .ObjFile: return "obj"
																// TODO: more
			default: return "unknown"
		}
	}

}