//
//  GenTarget.swift
//
//
//  Created by Kevin Rise on 23/10/2023.
//

import Foundation

public class GenTarget: Hashable {
	var guid: String
	var file: URL
	var name: String
	var type: TargetType
	var isDependency: Bool
	var dependencyNames: [String]?		// guid of the dependent/child target(s) 
	//var dependencyTargets: [GenTarget]?
	var dependencyTargets: Set<GenTarget>?
	var productReference: ProductReference?			// defined in PifCacheHandler
	var archiveTarget: Bool

	// A list of CompilerCommands relating to this target
	var commands: [CompilerCommand] = []

	// The name to use when writing IR to disk, 
	// 	use the productRef name, as that handles renaming (like from .xcconfig files)
	lazy var nameForOutput: String = {
		if let prName = productReference?.name {
			return prName
		} else {
			return self.name + "." + self.getPathExtension()
		}
	}()

	public enum TargetType: CustomStringConvertible {
		case Application
		case Framework
		case Bundle
		case Extension
		case Package
		case ObjFile
		case Test
		case Tool
		case Unknown

		public var description: String {
			switch self {
				case .Application: return "Application"
				case .Framework: return "Framework"
				case .Bundle: return "Bundle"
				case .Extension: return "Extension"
				case .Package: return "Package"
				case .ObjFile: return "ObjectFile"
				case .Test: return "Test"
				case .Tool: return "Tool"
				default: return "Unknown"
			}
		}
	}

	public init(guid: String, file: URL, name: String, typeName: String, productReference: ProductReference?, dependencyNames: [String]?) {
		self.guid = guid
		self.file = file
		self.name = name
		self.type = Self.getType(typeName: typeName)
		self.productReference = productReference
		self.isDependency = false
		self.dependencyNames = dependencyNames
		self.archiveTarget = false
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(ObjectIdentifier(self))
	}

	public static func ==(lhs: GenTarget, rhs: GenTarget) -> Bool {
		return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
	}

	private static func getType(typeName: String) -> TargetType {
		switch typeName {
			case "com.apple.product-type.application":
				return TargetType.Application
			case "com.apple.product-type.framework":
				return TargetType.Framework
			case "com.apple.product-type.bundle":
				return TargetType.Bundle
			case "wrapper.app-extension":						// TODO: fix
				return TargetType.Extension
			case "packageProduct":								
				return TargetType.Package
			case "com.apple.product-type.objfile":
				return TargetType.ObjFile
			case "com.apple.product-type.bundle.unit-test":
				return TargetType.Test
			case "com.apple.product-type.tool":
				return TargetType.Tool
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