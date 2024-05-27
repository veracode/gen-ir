import Foundation
import PIFSupport

class PIFCache {
	private let pifCachePath: URL
	private let workspace: PIF.Workspace

	var projects: [PIF.Project] {
		workspace.projects
	}

	var targets: [PIF.BaseTarget] {
		workspace
			.projects
			.flatMap { $0.targets }
	}

	enum Error: Swift.Error {
		case nonexistentCache(String)
		case pifError(Swift.Error)
	}

	init(buildCache: URL) throws {
		self.pifCachePath = try Self.pifCachePath(in: buildCache)

		do {
			let cache = try PIFParser(cachePath: pifCachePath, logger: logger)
			workspace = cache.workspace
		} catch {
			throw Error.pifError(error)
		}
	}

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

	private func fileReferences(for project: PIF.Project) -> [PIF.FileReference] {
		func resolveChildren(starting children: [PIF.Reference], result: inout [PIF.FileReference]) {
			for child in children {
				if let fileReference = child as? PIF.FileReference {
					result.append(fileReference)
				} else if let group = child as? PIF.Group {
					resolveChildren(starting: group.children, result: &result)
				} else {
					print("Unhandled reference type: \(child)")
				}
			}
		}

		var result = [PIF.FileReference]()
		resolveChildren(starting: project.groupTree.children, result: &result)
		return result
	}

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

struct PIFDependencyProvider: DependencyProviding {
	private let cache: PIFCache
	private var guidToTargets: [PIF.GUID: Target]

	init(targets: [Target], cache: PIFCache) {
		self.cache = cache

		self.guidToTargets = targets
			.reduce(into: [PIF.GUID: Target]()) { partial, target in
				partial[target.baseTarget.guid] = target
			}
	}

	private func resolveSwiftPackage(_ packageGUID: PIF.GUID) -> PIF.GUID? {
		let productToken = "PACKAGE-PRODUCT:"
		let targetToken = "PACKAGE-TARGET:"
		guard packageGUID.starts(with: productToken), let product = guidToTargets[packageGUID] else { return packageGUID }

		let productName = String(packageGUID.dropFirst(productToken.count))

		let productTargetDependencies = product
			.baseTarget
			.dependencies
			.filter { $0.targetGUID.starts(with: targetToken) }

		let productUnderlyingTargets = productTargetDependencies
			.filter { $0.targetGUID.dropFirst(targetToken.count) == productName }

		if productUnderlyingTargets.isEmpty && !productTargetDependencies.isEmpty {
			// We likely have a stub target here (i.e. a precompiled framework)
			// see https://github.com/apple/swift-package-manager/issues/6069 for more
			logger.debug("Resolving Swift Package (\(productName) - \(packageGUID)) resulted in no targets. Possible stub target in: \(productTargetDependencies)")
			return nil
		} else if productUnderlyingTargets.isEmpty && productTargetDependencies.isEmpty {
			logger.debug("Resolving Swift Package (\(productName) - \(packageGUID)) resulted in no targets. Likely a prebuilt dependency")
			return nil
		}

		guard productTargetDependencies.count == 1, let target = productTargetDependencies.first else {
			logger.debug("Expecting one matching package target - found \(productTargetDependencies.count): \(productTargetDependencies). Returning first match if it exists")
			return productTargetDependencies.first?.targetGUID
		}

		logger.debug("\(packageGUID) resolves to \(target.targetGUID)")
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
