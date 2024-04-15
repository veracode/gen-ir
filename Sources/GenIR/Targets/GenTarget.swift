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
	var dependencyGuids: [String]?					// guid of the static dependent/child target(s) 
	var dependencyTargets: Set<GenTarget>?			// static dependencies
	var frameworkGuids: [String]?					// guid of the dynamic dependencies
	var frameworkTargets: Set<GenTarget>?			// dynamic dependencies
	var productReference: ProductReference?			// defined in PifCacheHandler
	var archiveTarget: Bool							// is this target is the archive?  (we need to build for this target)
	var hasSource: Bool								// this target has compilable source code
	var dependenciesKnown: Bool						// we've walked the dep. tree for this target and know it

	// A list of CompilerCommands relating to this target
	var commands: Set<CompilerCommand> = []

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
		case applicationTarget
		case frameworkTarget
		case bundleTarget
		case extensionTarget
		case packageTarget
		case objfileTarget
		case testTarget
		case toolTarget
		case unknownTarget

		public var description: String {
			switch self {
				case .applicationTarget: return "Application"
				case .frameworkTarget: return "Framework"
				case .bundleTarget: return "Bundle"
				case .extensionTarget: return "Extension"
				case .packageTarget: return "Package"
				case .objfileTarget: return "ObjectFile"
				case .testTarget: return "Test"
				case .toolTarget: return "Tool"
				default: return "Unknown"
				}
		}
	}

	// swiftlint:disable vertical_parameter_alignment - swiftlint bug?
	public init(guid: String, file: URL, name: String, typeName: String,
				productReference: ProductReference?, dependencyGuids: [String]?, frameworkGuids: [String]?, hasSource: Bool) {
		self.guid = guid
		self.file = file
		self.name = name
		self.type = Self.getType(typeName: typeName)
		self.productReference = productReference
		self.dependencyGuids = dependencyGuids
		self.frameworkGuids = frameworkGuids
		self.archiveTarget = false
		self.hasSource = hasSource
		self.dependenciesKnown = false
	}
	// swiftlint:enable vertical_parameter_alignment

	public func hash(into hasher: inout Hasher) {
		hasher.combine(guid)
		hasher.combine(file)
	}

	// swiftlint:disable:next operator_whitespace
	public static func ==(lhs: GenTarget, rhs: GenTarget) -> Bool {
		// should be OK, as Xcode (should) assign unique GUIDs to each object
		// after all, that's what a 'guid' is, right?
		return lhs.guid == rhs.guid
	}

	private static func getType(typeName: String) -> TargetType {
		switch typeName {
			case "com.apple.product-type.application":
				return TargetType.applicationTarget
			case "com.apple.product-type.framework":
				return TargetType.frameworkTarget
			case "com.apple.product-type.bundle":
				return TargetType.bundleTarget
			case "com.apple.product-type.app-extension":
				return TargetType.extensionTarget
			case "packageProduct":
				return TargetType.packageTarget
			case "com.apple.product-type.objfile":
				return TargetType.objfileTarget
			case "com.apple.product-type.bundle.unit-test":
				return TargetType.testTarget
			case "com.apple.product-type.tool":
				return TargetType.toolTarget
			default:
				return TargetType.unknownTarget
			}
	}

	private func getPathExtension() -> String {
		switch type {
			case .applicationTarget: return "app"
			case .frameworkTarget: return "framework"
			case .packageTarget: return "package"
			case .objfileTarget: return "obj"
																// TODO: more?
			default: return "unknown"
			}
	}
}
