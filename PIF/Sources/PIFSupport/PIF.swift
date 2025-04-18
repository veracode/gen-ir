// ===----------------------------------------------------------------------=== //
//
// This source file contains derivative work from the Swift Open Source Project
//
// Copyright (c) 2014-2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
// ===----------------------------------------------------------------------=== //

/* Changes: Thomas Hedderwick:
	- adjust structures to allow for only decoding Xcode's PIF files found in DerivedData
	- adjust types to remove external dependencies on SPM
*/

// swiftlint:disable file_length type_body_length static_over_final_class
import Foundation

/// The Project Interchange Format (PIF) is a structured representation of the
/// project model created by clients (Xcode/SwiftPM) to send to XCBuild.
///
/// The PIF is a representation of the project model describing the static
/// objects which contribute to building products from the project, independent
/// of "how" the user has chosen to build those products in any particular
/// build. This information can be cached by XCBuild between builds (even
/// between builds which use different schemes or configurations), and can be
/// incrementally updated by clients when something changes.
public enum PIF {
	/// This is used as part of the signature for the high-level PIF objects, to ensure that changes to the PIF schema
	/// are represented by the objects which do not use a content-based signature scheme (workspaces and projects,
	/// currently).
	static let schemaVersion = 11

	/// The file extension for files in the PIF cache
	static let cacheFileExtension = "-json"

	/// The type used for identifying PIF objects.
	public typealias GUID = String

	public enum Error: Swift.Error {
		case decodingError(String)
		case userInfoError(String)
		case dataReadingFailure(String)
	}

	/// The top-level PIF object.
	public struct TopLevelObject: Decodable {
		public let workspace: PIF.Workspace

		public init(workspace: PIF.Workspace) {
			self.workspace = workspace
		}
	}

	public class TypedObject: Decodable {
		class var type: String {
			fatalError("\(self) missing implementation")
		}

		let type: String?

		fileprivate init() {
			type = Swift.type(of: self).type
		}

		private enum CodingKeys: CodingKey {
			case type
		}

		required public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			type = try container.decode(String.self, forKey: .type)
			logger.trace(" ---> Decoded TypedObject \(String(describing: type))")
		}
	}

	public final class Workspace: Decodable {
		public let guid: GUID
		public let name: String
		public let path: URL?
		public let projects: [Project]

		private enum CodingKeys: CodingKey {
			case guid, name, path, projects
		}

		public required init(from decoder: Decoder) throws {
			guard let cachePath = decoder.userInfo[.pifCachePath] as? URL else {
				throw Error.userInfoError("decoder's userInfo doesn't contain the required key .cachePath, or that value isn't a URL")
			}

			let container = try decoder.container(keyedBy: CodingKeys.self)

			guid = try container.decode(GUID.self, forKey: .guid)
			name = try container.decode(String.self, forKey: .name)
			path = try container.decodeIfPresent(URL.self, forKey: .path)
			logger.trace(" ---> Decoded Workspace: guid \(guid) name \(name) path \(path?.absoluteString ?? "<nil>" ) ")
			let projectPaths = try container.decode([String].self, forKey: .projects)
				.map {
					cachePath
						.appendingPathComponent("project")
						.appendingPathComponent("\($0)\(PIF.cacheFileExtension)")
				}
			projectPaths.forEach { URL in
				logger.trace("\t project path \(URL)")
			}

			let projectContents = try projectPaths
				.map {
					do {
						return try Data(contentsOf: $0)
					} catch {
						throw Error.dataReadingFailure(error.localizedDescription)
					}
				}

			projects = try projectContents
				.map {
					try PIFDecoder(cache: cachePath).decode(PIF.Project.self, from: $0)
				}
		}
	}

	/// A PIF project, consisting of a tree of groups and file references, a list of targets, and some additional
	/// information.
	public final class Project: Decodable {
		public let guid: GUID
		public let projectName: String?
		public let path: URL?
		public let projectDirectory: URL
		public let developmentRegion: String?
		public let buildConfigurations: [BuildConfiguration]
		public let targets: [BaseTarget]
		public let groupTree: Group

		private enum CodingKeys: CodingKey {
			case guid, projectName, projectIsPackage, path, projectDirectory, developmentRegion, defaultConfigurationName, buildConfigurations, targets, groupTree
		}

		public required init(from decoder: Decoder) throws {
			guard let cachePath = decoder.userInfo[.pifCachePath] as? URL else {
				throw Error.userInfoError("decoder's userInfo doesn't container required key .cachePath, or that value isn't a URL")
			}
			let container = try decoder.container(keyedBy: CodingKeys.self)

			guid = try container.decode(GUID.self, forKey: .guid)
			projectName = try container.decodeIfPresent(String.self, forKey: .projectName)
			path = try container.decodeIfPresent(URL.self, forKey: .path)
			projectDirectory = try container.decode(URL.self, forKey: .projectDirectory)
			developmentRegion = try container.decodeIfPresent(String.self, forKey: .developmentRegion)
			buildConfigurations = try container.decode([BuildConfiguration].self, forKey: .buildConfigurations)
			logger.trace(" ---> Decoded Project: guid \(guid) name \(projectName ?? "<nil>") path \(path?.absoluteString ?? "<nil>" ) ")

			let targetContents = try container.decode([String].self, forKey: .targets)
				.map {
					cachePath
						.appendingPathComponent("target")
						.appendingPathComponent("\($0)\(PIF.cacheFileExtension)")
				}
				.map {
					do {
						return try Data(contentsOf: $0)
					} catch {
						throw Error.dataReadingFailure(error.localizedDescription)
					}
				}

			targets = try targetContents.compactMap { targetData in
        let pifDecoder = PIFDecoder(cache: cachePath)
        let untypedTarget = try pifDecoder.decode(PIF.TypedObject.self, from: targetData)
				logger.trace("\t untyped target type: \(untypedTarget)")
        switch untypedTarget.type {
				case "aggregate":
					return try pifDecoder.decode(PIF.AggregateTarget.self, from: targetData)
				case "standard", "packageProduct":
					return try pifDecoder.decode(PIF.Target.self, from: targetData)
				default:
					logger.debug("Ignoring target \(untypedTarget) of type: \(untypedTarget.type ?? "<nil>")")
					return nil
				}
			}
			self.groupTree = try container.decode(Group.self, forKey: .groupTree)
		}
	}

	/// Abstract base class for all items in the group hierarchy.
	public class Reference: TypedObject {
		/// Determines the base path for a reference's relative path.

		public let guid: GUID

		/// Relative path of the reference.  It is usually a literal, but may in fact contain build settings.
		public let path: String

		/// Determines the base path for the reference's relative path.
		public let sourceTree: SourceTree

		/// Name of the reference, if different from the last path component (if not set, the last path component will
		/// be used as the name).
		public let name: String?

		private enum CodingKeys: CodingKey {
			case guid, sourceTree, path, name, type
		}

		public required init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			guid = try container.decode(String.self, forKey: .guid)
			sourceTree = try container.decode(SourceTree.self, forKey: .sourceTree)
			path = try container.decode(String.self, forKey: .path)
			name = try container.decodeIfPresent(String.self, forKey: .name)

			try super.init(from: decoder)
			logger.trace(" ---> Decoded Reference guid \(guid) name \(name ?? "<nil>") path (\(path))")
		}
	}

	public enum SourceTree: RawRepresentable, Decodable {

		public typealias RawValue = String

		/// Indicates that the path is relative to the source root (i.e. the "project directory").
		case sourceRoot

		/// Indicates that the path is relative to the path of the parent group.
		case group

		/// Indicates that the path is relative to the effective build directory (which varies depending on active
		/// scheme, active run destination, or even an overridden build setting.
		case builtProductsDir

		/// Indicates that the path is an absolute path.
		case absolute

		/// Indicates that the path is relative to the SDKROOT
		case sdkRoot

		/// Indicates that the path is relative to the DEVELOPER_DIR (normally in the Xcode.app bundle)
		case developerDir

		case unknown

		public var rawValue: Self.RawValue {
			switch self {
			case .sourceRoot:
				return "SOURCE_ROOT"
			case .group:
				return "<group>"
			case .builtProductsDir:
				return "BUILT_PRODUCTS_DIR"
			case .absolute:
				return "<absolute>"
			case .sdkRoot:
				return "SDKROOT"
			case .developerDir:
				return "DEVELOPER_DIR"
			case .unknown:
				return "<unknown>"
			}
		}

		public init(rawValue: Self.RawValue) {
			switch rawValue {
			case "SOURCE_ROOT":
				self = .sourceRoot
			case "<group>":
				self = .group
			case "BUILT_PRODUCTS_DIR":
				self = .builtProductsDir
			case "<absolute>":
				self = .absolute
			case "SDKROOT":
				self = .sdkRoot
			case "DEVELOPER_DIR":
				self = .developerDir
			default:
				self = .unknown
			}
		}

		public init(from decoder: Decoder) throws {
			let container = try decoder.singleValueContainer()
			let rawValue = try container.decode(String.self)
			self = SourceTree(rawValue: rawValue)
		}
	}

	/// A reference to a file system entity (a file, folder, etc).
	public final class FileReference: Reference {
		override class var type: String { "file" }

		public var fileType: String

		private enum CodingKeys: CodingKey {
			case fileType
		}

		public required init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			fileType = try container.decode(String.self, forKey: .fileType)
			logger.trace(" ---> Decoded FileType \(fileType)")

			try super.init(from: decoder)
		}
	}

	/// A group that can contain References (FileReferences and other Groups). The resolved path of a group is used as
	/// the base path for any child references whose source tree type is GroupRelative.
	public final class VariantGroup: Group {
		override class var type: String { "variantGroup" }

		private enum CodingKeys: CodingKey {
			case children, type
		}

		public required init(from decoder: Decoder) throws {
			try super.init(from: decoder)
		}
	}

	public final class VersionGroup: Group {
		override class var type: String { "versionGroup" }

		private enum CodingKeys: CodingKey {
			case children, type
		}

		public required init(from decoder: Decoder) throws {
			try super.init(from: decoder)
		}
	}

	/// A group that can contain References (FileReferences and other Groups). The resolved path of a group is used as
	/// the base path for any child references whose source tree type is GroupRelative.
	public class Group: Reference {
		override class var type: String { "group" }

		public let children: [Reference]

		private enum CodingKeys: CodingKey {
			case children, type
		}

		public required init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			let untypedChildren = try container.decodeIfPresent([TypedObject].self, forKey: .children) ?? []
			if !untypedChildren.isEmpty {
				var childrenContainer = try container.nestedUnkeyedContainer(forKey: .children)

				children = try untypedChildren.compactMap { child in
					logger.trace(" ---> Decoded Group Type \(child.type ?? "<nil>")")
					switch child.type {
					case Group.type:
						return try childrenContainer.decode(Group.self)
					case VariantGroup.type:
						return try childrenContainer.decode(VariantGroup.self)
					case VersionGroup.type:
						return try childrenContainer.decode(VersionGroup.self)
					case FileReference.type:
						return try childrenContainer.decode(FileReference.self)
					default:
						logger.debug("Ignoring reference type: \(child.type ?? "<nil>")")
						return nil
					}
				}
			} else {
				children = []
			}

			try super.init(from: decoder)
		}
	}

	/// Represents a dependency on another target (identified by its PIF GUID).
	public struct TargetDependency: Decodable {
		/// Identifier of depended-upon target.
		public let targetGUID: String

		/// The platform filters for this target dependency.
		public let platformFilters: [PlatformFilter]

		private enum CodingKeys: CodingKey {
			case guid, platformFilters
		}

		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			targetGUID = try container.decode(String.self, forKey: .guid)
			platformFilters = try container.decodeIfPresent([PlatformFilter].self, forKey: .platformFilters) ?? []
			logger.trace("---> Decoded TargetDependency: \(targetGUID)")
		}
	}

	public class BaseTarget: TypedObject {
		class override var type: String { "target" }

		public let guid: GUID
		public let name: String
		public let buildConfigurations: [BuildConfiguration]
		public let buildPhases: [BuildPhase]
		public let dependencies: [TargetDependency]
		public let impartedBuildProperties: ImpartedBuildProperties?

		fileprivate init(
			guid: GUID,
			name: String,
			buildConfigurations: [BuildConfiguration],
			buildPhases: [BuildPhase],
			dependencies: [TargetDependency],
			impartedBuildSettings: PIF.BuildSettings?
		) {
			self.guid = guid
			self.name = name
			self.buildConfigurations = buildConfigurations
			self.buildPhases = buildPhases
			self.dependencies = dependencies
			self.impartedBuildProperties = ImpartedBuildProperties(buildSettings: impartedBuildSettings ?? .init())
			super.init()
		}

		public required init(from decoder: Decoder) throws {
			throw Error.decodingError("init(from:) has not been implemented")
		}
	}

	public final class AggregateTarget: BaseTarget {
		private enum CodingKeys: CodingKey {
			case type, guid, name, buildConfigurations, buildPhases, dependencies, impartedBuildProperties
		}

		public required init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			let guid = try container.decode(GUID.self, forKey: .guid)
			let name = try container.decode(String.self, forKey: .name)
			let buildConfigurations = try container.decode([BuildConfiguration].self, forKey: .buildConfigurations)

			let untypedBuildPhases = try container.decode([TypedObject].self, forKey: .buildPhases)
			var buildPhasesContainer = try container.nestedUnkeyedContainer(forKey: .buildPhases)

			let buildPhases: [BuildPhase] = try untypedBuildPhases.compactMap {
				guard let type = $0.type else {
					throw Error.decodingError("Expected type in build phase \($0)")
				}
				return try BuildPhase.decode(container: &buildPhasesContainer, type: type)
			}

			let dependencies = try container.decode([TargetDependency].self, forKey: .dependencies)
			let impartedBuildProperties = try container.decodeIfPresent(BuildSettings.self, forKey: .impartedBuildProperties)
			logger.trace("---> Decoded BaseTarget: guid \(guid) name \(name)")

			super.init(
				guid: guid,
				name: name,
				buildConfigurations: buildConfigurations,
				buildPhases: buildPhases,
				dependencies: dependencies,
				impartedBuildSettings: impartedBuildProperties
			)
		}
	}

	/// An Xcode target, representing a single entity to build.
	public final class Target: BaseTarget {
		public enum ProductType: String, Decodable {
			case appExtension = "com.apple.product-type.app-extension"
			case appExtensionMessages = "com.apple.product-type.app-extension.messages"
			case stickerPackExtension = "com.apple.product-type.app-extension.messages-sticker-pack"
			case application = "com.apple.product-type.application"
			case applicationMessages = "com.apple.product-type.application.messages"
			case appClip = "com.apple.product-type.application.on-demand-install-capable"
			case bundle = "com.apple.product-type.bundle"
			case externalTest = "com.apple.product-type.bundle.external-test"
			case ocUnitTest = "com.apple.product-type.bundle.ocunit-test"
			case uiTesting = "com.apple.product-type.bundle.ui-testing"
			case unitTest = "com.apple.product-type.bundle.unit-test"
			case extensionKitExtension = "com.apple.product-type.extensionkit-extension"
			case framework = "com.apple.product-type.framework"
			case staticFramework = "com.apple.product-type.framework.static"
			case instrumentsPackage = "com.apple.product-type.instruments-package"
			case kernelExtension = "com.apple.product-type.kernel-extension"
			case ioKitKernelExtension = "com.apple.product-type.kernel-extension.iokit"
			case dynamicLibrary = "com.apple.product-type.library.dynamic"
			case staticLibrary = "com.apple.product-type.library.static"
			case objectFile = "com.apple.product-type.objfile"
			case pluginKitPlugin = "com.apple.product-type.pluginkit-plugin"
			case packageProduct = "packageProduct"
			case systemExtension = "com.apple.product-type.system-extension"
			case tool = "com.apple.product-type.tool"
			case hostBuild = "com.apple.product-type.tool.host-build"
			case xpcService = "com.apple.product-type.xpc-service"
			case watchApp2 = "com.apple.product-type.application.watchapp2"
			case watchApp2Container = "com.apple.product-type.application.watchapp2-container"
			case watchKit2Extension = "com.apple.product-type.watchkit2-extension"
		}

		public let productName: String
		public let productType: ProductType

		private enum CodingKeys: CodingKey {
			case guid, name, dependencies, buildConfigurations, type, frameworksBuildPhase, productTypeIdentifier, productReference, buildRules, buildPhases, impartedBuildProperties
		}

		public required init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			// The swift package manager drops the length of schemaVersion from the end of the guid-string. However, 
			// this doesn't work for all guids, because some are names and not guid strings (PackageProduct?).
			let guid = try container.decode(GUID.self, forKey: .guid)
			let name = try container.decode(String.self, forKey: .name)
			let buildConfigurations = try container.decode([BuildConfiguration].self, forKey: .buildConfigurations)
			let dependencies = try container.decode([TargetDependency].self, forKey: .dependencies)
			let type = try container.decode(String.self, forKey: .type)

			let buildPhases: [BuildPhase]
			let impartedBuildProperties: ImpartedBuildProperties
			logger.trace("---> Decoded Target: guid \(guid) name \(name)")

			if type == "packageProduct" {
				self.productType = .packageProduct
				self.productName = ""
				let fwkBuildPhase = try container.decodeIfPresent(FrameworksBuildPhase.self, forKey: .frameworksBuildPhase)
				buildPhases = fwkBuildPhase.map { [$0] } ?? []
				impartedBuildProperties = ImpartedBuildProperties(buildSettings: BuildSettings())
			} else if type == "standard" {
				self.productType = try container.decode(ProductType.self, forKey: .productTypeIdentifier)

				let productReference = try container.decode([String: String].self, forKey: .productReference)
				self.productName = productReference["name"]!

				let untypedBuildPhases = try container.decodeIfPresent([TypedObject].self, forKey: .buildPhases) ?? []
				var buildPhasesContainer = try container.nestedUnkeyedContainer(forKey: .buildPhases)

				buildPhases = try untypedBuildPhases.compactMap {
					guard let type = $0.type else {
						throw Error.decodingError("Expected type in build phase \($0)")
					}
					return try BuildPhase.decode(container: &buildPhasesContainer, type: type)
				}

				impartedBuildProperties = try container.decodeIfPresent(ImpartedBuildProperties.self, forKey: .impartedBuildProperties) ?? .init(buildSettings: .init())
			} else {
				throw Error.decodingError("Unhandled target type \(type)")
			}

			super.init(
				guid: guid,
				name: name,
				buildConfigurations: buildConfigurations,
				buildPhases: buildPhases,
				dependencies: dependencies,
				impartedBuildSettings: impartedBuildProperties.buildSettings
			)
			logger.trace(" ---> Target \(name) with guid \(guid) and product type \(productType) and product name \(productName) decoded")
		}
	}

	/// Abstract base class for all build phases in a target.
	public class BuildPhase: TypedObject {
		static func decode(container: inout UnkeyedDecodingContainer, type: String) throws -> BuildPhase? {
			logger.trace("---> Decoded BuildPhase: type \(type)")
			switch type {
			case HeadersBuildPhase.type:
				return try container.decode(HeadersBuildPhase.self)
			case SourcesBuildPhase.type:
				return try container.decode(SourcesBuildPhase.self)
			case FrameworksBuildPhase.type:
				return try container.decode(FrameworksBuildPhase.self)
			case ResourcesBuildPhase.type:
				return try container.decode(ResourcesBuildPhase.self)
			case CopyFilesBuildPhase.type:
				return try container.decode(CopyFilesBuildPhase.self)
			case ShellScriptBuildPhase.type:
				return try container.decode(ShellScriptBuildPhase.self)
			default:
				logger.debug("Ignoring build phase: \(type)")
				return nil
			}
		}

		public let guid: GUID
		public let buildFiles: [BuildFile]

		private enum CodingKeys: CodingKey {
			case guid, buildFiles
		}

		public required init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			guid = try container.decode(GUID.self, forKey: .guid)
			buildFiles = try container.decode([BuildFile].self, forKey: .buildFiles)
			logger.trace("\tBuildPhase guid \(guid)")

			try super.init(from: decoder)
		}
	}

	/// A "headers" build phase, i.e. one that copies headers into a directory of the product, after suitable
	/// processing.
	public final class HeadersBuildPhase: BuildPhase {
		override class var type: String { "com.apple.buildphase.headers" }
	}

	/// A "sources" build phase, i.e. one that compiles sources and provides them to be linked into the executable code
	/// of the product.
	public final class SourcesBuildPhase: BuildPhase {
		override class var type: String { "com.apple.buildphase.sources" }
	}

	/// A "frameworks" build phase, i.e. one that links compiled code and libraries into the executable of the product.
	public final class FrameworksBuildPhase: BuildPhase {
		override class var type: String { "com.apple.buildphase.frameworks" }
	}

	public final class ResourcesBuildPhase: BuildPhase {
		override class var type: String { "com.apple.buildphase.resources" }
	}

	public final class CopyFilesBuildPhase: BuildPhase {
		override class var type: String { "com.apple.buildphase.copy-files" }
	}

	public final class ShellScriptBuildPhase: BuildPhase {
		override class var type: String { "com.apple.buildphase.shell-script" }
	}

	/// A build file, representing the membership of either a file or target product reference in a build phase.
	public struct BuildFile: Decodable {
		public enum Reference {
			case file(guid: PIF.GUID)
			case target(guid: PIF.GUID)
		}

		public enum HeaderVisibility: String, Decodable {
			case `public` = "public"
			case `private` = "private"
		}

		public let guid: GUID
		public let reference: Reference
		public let headerVisibility: HeaderVisibility?
		public let platformFilters: [PlatformFilter]

		private enum CodingKeys: CodingKey {
			case guid, platformFilters, fileReference, targetReference, headerVisibility
		}

		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			guid = try container.decode(GUID.self, forKey: .guid)
			platformFilters = try container.decodeIfPresent([PlatformFilter].self, forKey: .platformFilters) ?? []
			headerVisibility = try container.decodeIfPresent(HeaderVisibility.self, forKey: .headerVisibility) ?? nil
			logger.trace("---> Decoded BuildFile:  guid \(guid) visibility \(headerVisibility?.rawValue ?? "<nil>")")

			if container.allKeys.contains(.fileReference) {
				reference = try .file(guid: container.decode(GUID.self, forKey: .fileReference))
			} else if container.allKeys.contains(.targetReference) {
				reference = .target(guid: try container.decode(GUID.self, forKey: .targetReference))
			} else {
				throw Error.decodingError("Expected \(CodingKeys.fileReference) or \(CodingKeys.targetReference) in the keys")
			}
		}
	}

	/// Represents a generic platform filter.
	public struct PlatformFilter: Decodable, Equatable {
		/// The name of the platform (`LC_BUILD_VERSION`).
		///
		/// Example: macos, ios, watchos, tvos.
		public let platform: String

		/// The name of the environment (`LC_BUILD_VERSION`)
		///
		/// Example: simulator, maccatalyst.
		public let environment: String?
	}

	/// A build configuration, which is a named collection of build settings.
	public struct BuildConfiguration: Decodable {
		public let guid: GUID
		public let name: String
		public let buildSettings: BuildSettings
		public let impartedBuildProperties: ImpartedBuildProperties

		private enum CodingKeys: CodingKey {
			case guid, name, buildSettings, impartedBuildProperties
		}

		public init(from decoder: any Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			guid = try container.decode(GUID.self, forKey: .guid)
			name = try container.decode(String.self, forKey: .name)
			buildSettings = try container.decode(BuildSettings.self, forKey: .buildSettings)
			impartedBuildProperties  = try container.decodeIfPresent(ImpartedBuildProperties.self, forKey: .impartedBuildProperties) ?? .init(buildSettings: .init())
			logger.trace("---> Decoded BuildConfiguration: guid \(guid) name \(name)")
		}
	}

	public struct ImpartedBuildProperties: Decodable {
		public let buildSettings: BuildSettings
	}

	// swiftlint:disable identifier_name inclusive_language
	/// A set of build settings, which is represented as a struct of optional build settings. This is not optimally
	/// efficient, but it is great for code completion and type-checking.
	public struct BuildSettings: Decodable {
		public enum SingleValueSetting: String, Decodable {
			case APPLICATION_EXTENSION_API_ONLY
			case BUILT_PRODUCTS_DIR
			case CLANG_CXX_LANGUAGE_STANDARD
			case CLANG_ENABLE_MODULES
			case CLANG_ENABLE_OBJC_ARC
			case CODE_SIGNING_REQUIRED
			case CODE_SIGN_IDENTITY
			case COMBINE_HIDPI_IMAGES
			case COPY_PHASE_STRIP
			case DEBUG_INFORMATION_FORMAT
			case DEFINES_MODULE
			case DRIVERKIT_DEPLOYMENT_TARGET
			case DYLIB_INSTALL_NAME_BASE
			case EMBEDDED_CONTENT_CONTAINS_SWIFT
			case ENABLE_NS_ASSERTIONS
			case ENABLE_TESTABILITY
			case ENABLE_TESTING_SEARCH_PATHS
			case ENTITLEMENTS_REQUIRED
			case EXECUTABLE_NAME
			case GENERATE_INFOPLIST_FILE
			case GCC_C_LANGUAGE_STANDARD
			case GCC_OPTIMIZATION_LEVEL
			case GENERATE_MASTER_OBJECT_FILE
			case INFOPLIST_FILE
			case IPHONEOS_DEPLOYMENT_TARGET
			case KEEP_PRIVATE_EXTERNS
			case CLANG_COVERAGE_MAPPING_LINKER_ARGS
			case MACH_O_TYPE
			case MACOSX_DEPLOYMENT_TARGET
			case MODULEMAP_FILE
			case MODULEMAP_FILE_CONTENTS
			case MODULEMAP_PATH
			case MODULE_CACHE_DIR
			case ONLY_ACTIVE_ARCH
			case PACKAGE_RESOURCE_BUNDLE_NAME
			case PACKAGE_RESOURCE_TARGET_KIND
			case PRODUCT_BUNDLE_IDENTIFIER
			case PRODUCT_MODULE_NAME
			case PRODUCT_NAME
			case PROJECT_NAME
			case SDKROOT
			case SDK_VARIANT
			case SKIP_INSTALL
			case INSTALL_PATH
			case SUPPORTS_MACCATALYST
			case SWIFT_SERIALIZE_DEBUGGING_OPTIONS
			case SWIFT_FORCE_STATIC_LINK_STDLIB
			case SWIFT_FORCE_DYNAMIC_LINK_STDLIB
			case SWIFT_INSTALL_OBJC_HEADER
			case SWIFT_OBJC_INTERFACE_HEADER_NAME
			case SWIFT_OBJC_INTERFACE_HEADER_DIR
			case SWIFT_OPTIMIZATION_LEVEL
			case SWIFT_VERSION
			case TARGET_NAME
			case TARGET_BUILD_DIR
			case TVOS_DEPLOYMENT_TARGET
			case USE_HEADERMAP
			case USES_SWIFTPM_UNSAFE_FLAGS
			case WATCHOS_DEPLOYMENT_TARGET
			case XROS_DEPLOYMENT_TARGET
			case MARKETING_VERSION
			case CURRENT_PROJECT_VERSION
			case SWIFT_EMIT_MODULE_INTERFACE
			case GENERATE_RESOURCE_ACCESSORS
		}

		public enum MultipleValueSetting: String, Decodable {
			case EMBED_PACKAGE_RESOURCE_BUNDLE_NAMES
			case FRAMEWORK_SEARCH_PATHS
			case GCC_PREPROCESSOR_DEFINITIONS
			case HEADER_SEARCH_PATHS
			case LD_RUNPATH_SEARCH_PATHS
			case LIBRARY_SEARCH_PATHS
			case OTHER_CFLAGS
			case OTHER_CPLUSPLUSFLAGS
			case OTHER_LDFLAGS
			case OTHER_LDRFLAGS
			case OTHER_SWIFT_FLAGS
			case PRELINK_FLAGS
			case SPECIALIZATION_SDK_OPTIONS
			case SUPPORTED_PLATFORMS
			case SWIFT_ACTIVE_COMPILATION_CONDITIONS
			case SWIFT_MODULE_ALIASES
		}
		// swiftlint:enable identifier_name inclusive_language

		public enum Platform: String, CaseIterable, Decodable {
			case macOS = "macos"
			case macCatalyst = "maccatalyst"
			case iOS = "ios"
			case tvOS = "tvos"
			case watchOS = "watchos"
			case driverKit = "driverkit"
			case linux
		}

		public private(set) var platformSpecificSingleValueSettings = [Platform: [SingleValueSetting: String]]()
		public private(set) var platformSpecificMultipleValueSettings = [Platform: [MultipleValueSetting: [String]]]()
		public private(set) var singleValueSettings: [SingleValueSetting: String] = [:]
		public private(set) var multipleValueSettings: [MultipleValueSetting: [String]] = [:]

		public subscript(_ setting: SingleValueSetting) -> String? {
			get { singleValueSettings[setting] }
			set { singleValueSettings[setting] = newValue }
		}

		public subscript(_ setting: SingleValueSetting, for platform: Platform) -> String? {
			get { platformSpecificSingleValueSettings[platform]?[setting] }
			set { platformSpecificSingleValueSettings[platform, default: [:]][setting] = newValue }
		}

		public subscript(_ setting: SingleValueSetting, default defaultValue: @autoclosure () -> String) -> String {
			get { singleValueSettings[setting, default: defaultValue()] }
			set { singleValueSettings[setting] = newValue }
		}

		public subscript(_ setting: MultipleValueSetting) -> [String]? {
			get { multipleValueSettings[setting] }
			set { multipleValueSettings[setting] = newValue }
		}

		public subscript(_ setting: MultipleValueSetting, for platform: Platform) -> [String]? {
			get { platformSpecificMultipleValueSettings[platform]?[setting] }
			set { platformSpecificMultipleValueSettings[platform, default: [:]][setting] = newValue }
		}

		public subscript(
			_ setting: MultipleValueSetting,
			default defaultValue: @autoclosure () -> [String]
		) -> [String] {
			get { multipleValueSettings[setting, default: defaultValue()] }
			set { multipleValueSettings[setting] = newValue }
		}

		public subscript(
			_ setting: MultipleValueSetting,
			for platform: Platform,
			default defaultValue: @autoclosure () -> [String]
		) -> [String] {
			get { platformSpecificMultipleValueSettings[platform, default: [:]][setting, default: defaultValue()] }
			set { platformSpecificMultipleValueSettings[platform, default: [:]][setting] = newValue }
		}

		public init() {}

		private enum CodingKeys: CodingKey {
			case platformSpecificSingleValueSettings, platformSpecificMultipleValueSettings, singleValueSettings, multipleValueSettings
		}

		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			platformSpecificSingleValueSettings = try container.decodeIfPresent([Platform: [SingleValueSetting: String]].self, forKey: .platformSpecificSingleValueSettings) ?? .init()
			platformSpecificMultipleValueSettings = try container.decodeIfPresent([Platform: [MultipleValueSetting: [String]]].self, forKey: .platformSpecificMultipleValueSettings) ?? .init()
			singleValueSettings = try container.decodeIfPresent([SingleValueSetting: String].self, forKey: .singleValueSettings) ?? [:]
			multipleValueSettings = try container.decodeIfPresent([MultipleValueSetting: [String]] .self, forKey: .multipleValueSettings) ?? [:]
		}
	}
}

/// Represents a filetype recognized by the Xcode build system.
public struct XCBuildFileType: CaseIterable {
	public static let xcdatamodeld: XCBuildFileType = XCBuildFileType(
		fileType: "xcdatamodeld",
		fileTypeIdentifier: "wrapper.xcdatamodeld"
	)

	public static let xcdatamodel: XCBuildFileType = XCBuildFileType(
		fileType: "xcdatamodel",
		fileTypeIdentifier: "wrapper.xcdatamodel"
	)

	public static let xcmappingmodel: XCBuildFileType = XCBuildFileType(
		fileType: "xcmappingmodel",
		fileTypeIdentifier: "wrapper.xcmappingmodel"
	)

	public static let allCases: [XCBuildFileType] = [
		.xcdatamodeld,
		.xcdatamodel,
		.xcmappingmodel
	]

	public let fileTypes: Set<String>
	public let fileTypeIdentifier: String

	private init(fileTypes: Set<String>, fileTypeIdentifier: String) {
		self.fileTypes = fileTypes
		self.fileTypeIdentifier = fileTypeIdentifier
	}

	private init(fileType: String, fileTypeIdentifier: String) {
		self.init(fileTypes: [fileType], fileTypeIdentifier: fileTypeIdentifier)
	}
}

private struct UntypedTarget: Decodable {
	struct TargetContents: Decodable {
		let type: String
	}
	let contents: TargetContents
}
// swiftlint:enable file_length type_body_length static_over_final_class
