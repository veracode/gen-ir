import Foundation
import PIFSupport
import DependencyGraph
import LogHandlers

/// The PIFCache provides a wrapper around a `PIF.Workspace`.
/// It includes a set of helper functions to make operating on the PIF Cache structures easier.
/// This class is used in conjunction with `PIFDependencyProvider` to enable building dependency relationships between the various targets
class PIFCache {
	/// The path to the PIF Cache
	private let pifCachePath: URL

	/// The most recent `PIF.Workspace` in the cache
	private let workspace: PIF.Workspace

	/// All projects contained by the workspace
	var projects: [PIF.Project] {
		workspace.projects
	}

	/// All targets contained by the workspace
	var targets: [PIF.BaseTarget] {
		workspace
			.projects
			.flatMap { $0.targets }
	}

	enum Error: Swift.Error {
		case nonexistentCache(String)
		case pifError(Swift.Error)
	}

	/// Initializes the PIF Cache from a build cache
	/// - Parameter buildCache: path to the Xcode DerivedData Build Cache
	init(buildCache: URL) throws {
		self.pifCachePath = try Self.pifCachePath(in: buildCache)

		do {
			let cache = try PIFCacheParser(cachePath: pifCachePath, logger: logger)
			workspace = cache.workspace
		} catch {
			throw Error.pifError(error)
		}
	}

	/// Finds the PIF Cache in the Xcode Build Cache. This can vary depending on the build system used.
	/// - Parameter buildCache: the Xcode build cache
	/// - Throws: if no cache was found
	/// - Returns: the path to the PIF Cache
	private static func pifCachePath(in buildCache: URL) throws -> URL {
		let cmakePIFCachePath = buildCache
				.appendingPathComponent("XCBuildData")
				.appendingPathComponent("PIFCache")

		let regularPIFCachePath = buildCache
				.appendingPathComponent("Build")
				.appendingPathComponent("Intermediates.noindex")
				.appendingPathComponent("XCBuildData")
				.appendingPathComponent("PIFCache")

		if FileManager.default.directoryExists(at: cmakePIFCachePath) {
			return cmakePIFCachePath
		} else if FileManager.default.directoryExists(at: regularPIFCachePath) {
			return regularPIFCachePath
		} else {
			throw Error.nonexistentCache(
				"""
				Couldn't find cache at: \(regularPIFCachePath). Ensure a clean build **AND** \
				ensure `xcodebuild clean` happens separately from `xcodebuild archive` command
				"""
			)
		}
	}

	/// Recursively gets all file references inside a given project
	/// This will not return Groups, it will attempt to resolve them to the underlying file references
	/// - Parameter project: the project to find file references in
	/// - Returns: a list of file references
	private func fileReferences(for project: PIF.Project) -> [PIF.FileReference] {
		var result = [PIF.FileReference]()
		/// Recursively resolve references to file references
		/// - Parameters:
		///   - children: the starting list of references
		func resolveChildren(starting children: [PIF.Reference]) {
			children.forEach { child in
				switch child {
				case let file as PIF.FileReference:
					result.append(file)
				case let group as PIF.Group:
					resolveChildren(starting: group.children)
				default:
					logger.debug("Unhandled reference type: \(child)")
				}
			}
		}

		resolveChildren(starting: project.groupTree.children)
		return result
	}

	/// A mapping of Framework `PIF.GUID`s to the framework `PIF.Target`
	lazy var frameworks: [PIF.GUID: PIF.Target] = {
		// Here we have to get all the wrapper.framework references from the group, and then attempt to map them to targets
		let frameworkFileReferences = projects
			.flatMap { fileReferences(for: $0) }
			.filter { $0.fileType == "wrapper.framework" }

		// Now, stupidly, we have to do a name lookup on the path and use that to look up a target
		let frameworks = targets
			.compactMap { $0 as? PIF.Target }
			.filter { $0.productType == .framework }
			.reduce(into: [String: PIF.Target]()) { partial, target in
				let key = target.productName.isEmpty ? target.guid : target.productName
				partial[key] = target
			}

		return frameworkFileReferences
			.reduce(into: [PIF.GUID: PIF.Target]()) { partial, fileReference in
				// Use the _file reference_ GUID as the key here - we're looking up frameworks by their file reference and not target GUID!
				partial[fileReference.guid] = frameworks[fileReference.path]
			}
	}()
}

extension PIF.BaseTarget: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(ObjectIdentifier(self))
	}

	public static func == (lhs: PIF.BaseTarget, rhs: PIF.BaseTarget) -> Bool {
		ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
	}
}

// TODO: think if there is a better type enforced way of defining the relationships here - should this be in the Targets file (and called TargetDependencyProvider)

/// The PIFDependencyProvider is responsible for calculating dependency relationships between targets in the cache
struct PIFDependencyProvider: DependencyProviding {
	/// The `PIFCache` to provide dependency relationships for
	private let cache: PIFCache

	/// A mapping of `PIF.GUID` to the `Target` they represent
	private var guidToTargets: [PIF.GUID: Target]

	// / Initializes the PIFDependencyProvider
	/// - Parameters:
	///   - targets: the list of targets to provide dependency relationships for
	///   - cache: the cache that contains the targets
	init(targets: [Target], cache: PIFCache) {
		self.cache = cache

		self.guidToTargets = targets
			.reduce(into: [PIF.GUID: Target]()) { partial, target in
				partial[target.baseTarget.guid] = target
			}
	}

	/// Attempts to resolve a Swift Package Product reference to it's Swift Package Target reference
	/// When SPM generates PIF files relating to the package you (typically) end up with 4 PIF Targets:
	///  - Package Product:
	///    - This depends on the Package Target
	///    - This has a dynamic target variant pointing to the Dynamic Package Product
	///  - Dynamic Package Product
	///    - This depends on the Package Target
	///  - Package Target
	///    - This is the object file that is the actual target we're looking for
	///    - This has a dynamic target variant pointing to the Dynamic Package Target
	///  - Dynamic Package Target
	/// Typically, we want to take the Package Product and find the Package Target it depends on
	/// - Parameter packageProductGUID: the swift product package guid
	/// - Returns: the guid of the related Swift Package Target
	private func resolveSwiftPackage(_ packageProductGUID: PIF.GUID) -> PIF.GUID? {
		let productToken = "PACKAGE-PRODUCT:"
		let targetToken = "PACKAGE-TARGET:"
		guard packageProductGUID.starts(with: productToken), let product = guidToTargets[packageProductGUID] else { return packageProductGUID }

		let productName = String(packageProductGUID.dropFirst(productToken.count))

		let productTargetDependencies = product
			.baseTarget
			.dependencies
			.filter { $0.targetGUID.starts(with: targetToken) }

		let productUnderlyingTargets = productTargetDependencies
			.filter { $0.targetGUID.dropFirst(targetToken.count) == productName }

		if productUnderlyingTargets.isEmpty && !productTargetDependencies.isEmpty {
			// We likely have a stub target here (i.e. a precompiled framework)
			// see https://github.com/apple/swift-package-manager/issues/6069 for more
			logger.debug("Resolving Swift Package (\(productName) - \(packageProductGUID)) resulted in no targets. Possible stub target in: \(productTargetDependencies)")
			return nil
		} else if productUnderlyingTargets.isEmpty && productTargetDependencies.isEmpty {
			logger.debug("Resolving Swift Package (\(productName) - \(packageProductGUID)) resulted in no targets. Likely a prebuilt dependency")
			return nil
		}

		guard productTargetDependencies.count == 1, let target = productTargetDependencies.first else {
			logger.debug("Expecting one matching package target - found \(productTargetDependencies.count): \(productTargetDependencies). Returning first match if it exists")
			return productTargetDependencies.first?.targetGUID
		}

		logger.debug("\(packageProductGUID) resolves to \(target.targetGUID)")
		return target.targetGUID
	}

	func dependencies(for value: Target) -> [Target] {
		// Direct dependencies
		let dependencyTargetGUIDs = value
			.baseTarget
			.dependencies
			.map { $0.targetGUID }
			.compactMap { resolveSwiftPackage($0) }

		// Framework build phase dependencies
		// NOTE: Previously we just cast this - all of a sudden with pods this is broken
		// Not the end of the world - just as quick to do a dictionary lookup
		let frameworkGUIDs = value
			.baseTarget
			.buildPhases
			.flatMap { $0.buildFiles }
			// .compactMap { $0 as? PIF.FrameworksBuildPhase }
			.compactMap {
				switch $0.reference {
				case let .file(guid): return guid
				case .target: return nil
				}
			}
			.compactMap { cache.frameworks[$0]?.guid }

		let dependencyTargets = (dependencyTargetGUIDs + frameworkGUIDs).compactMap { guidToTargets[$0] }

		return dependencyTargets
	}
}
