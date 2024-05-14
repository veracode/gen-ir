import Foundation
import PIFSupport

class PIFCache {
	private let buildCache: URL
	private let pifCachePath: URL
	private let workspace: PIF.Workspace

	enum Error: Swift.Error {
		case nonexistentCache(String)
		case pifError(Swift.Error)
	}

	init(buildCache: URL) throws {
		self.buildCache = buildCache
		self.pifCachePath = try Self.pifCachePath(in: buildCache)

		do {
			let cache = try PIFParser(cachePath: pifCachePath)
			workspace = cache.workspace
		} catch {
			throw Error.pifError(error)
		}
	}

	private static func pifCachePath(in buildCache: URL) throws -> URL {
		// TODO: test this variation, because I haven't seen this personally
		let cmakePIFCachePath = buildCache
				.deletingLastPathComponent()
				.appendingPathComponent("XCBuildData")
				.appendingPathComponent("PIFCache")

		let regularPIFCachePath = buildCache
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

	var projects: [PIF.Project] {
		workspace.projects
	}

	// private lazy var projectsByGUID: [GUID: PIF.Project] = {
	// 	workspace
	// 		.projects
	// 		.reduce(into: [GUID: PIF.Project]()) { result, element in
	// 			result[element.guid] = element
	// 		}
	// }()

	// func project(for guid: GUID) -> PIF.Project? {
	// 	projectsByGUID[guid]
	// }

	// TODO: We cab possibly filter out some targets here for performance
	var targets: [PIF.BaseTarget] {
		workspace
			.projects
			.flatMap { $0.targets }
	}

	private lazy var namesToTargets: [String: PIF.BaseTarget] = {
		targets
			.reduce(into: [String: PIF.BaseTarget]()) { partial, target in
				partial[target.name] = target
			}
	}()

	private lazy var productNamesToTargets: [String: PIF.BaseTarget] = {
		targets
			.compactMap { $0 as? PIF.Target }
			.reduce(into: [String: PIF.BaseTarget]()) { partial, target in
				partial[target.productName] = target
			}
	}()

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
			// TODO: do we filter on sourceTree == "BUILT_PRODUCTS_DIR" here too?

		// Now, stupidly, we have to do a name lookup on the path and use that to look up a target
		let frameworks = targets
			.compactMap { $0 as? PIF.Target }
			.filter { $0.productType == .framework }
			.reduce(into: [String: PIF.Target]()) { partial, target in
				partial[target.productName] = target
			}

		return frameworkFileReferences
			// .compactMap { frameworks[$0.path] } // TODO: I think we should get the last path component as the key here - check that
			.reduce(into: [PIF.GUID: PIF.Target]()) { partial, fileReference in
				// partial[target.guid] = target
				// Use the _file reference_ GUID as the key here - we're looking up frameworks by their file reference and not target GUID!
				partial[fileReference.guid] = frameworks[fileReference.path]
			}
	}()

	// private lazy var targetsByGUID: [GUID: PIF.BaseTarget] = {
	// 	targets
	// 		.reduce(into: [GUID: PIF.BaseTarget]()) { result, element in
	// 			result[element.guid] = element
	// 		}
	// }()

	// func target(for guid: GUID) -> PIF.BaseTarget? {
	// 	targetsByGUID[guid]
	// }
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
	private let targets: [Target]
	private let cache: PIFCache
	private var guidToTargets: [PIF.GUID: Target]

	init(targets: [Target], cache: PIFCache) {
		self.targets = targets
		self.cache = cache

		self.guidToTargets = targets
			.reduce(into: [PIF.GUID: Target]()) { partial, target in
				partial[target.baseTarget.guid] = target
			}
	}

	private func resolveSwiftPackage(_ packageGUID: PIF.GUID) -> PIF.GUID {
		let productToken = "PACKAGE-PRODUCT:"
		let targetToken = "PACKAGE-TARGET:"
		guard packageGUID.starts(with: productToken), let product = guidToTargets[packageGUID] else { return packageGUID }

		let productName = String(packageGUID.dropFirst(productToken.count))

		// TODO: should this also use the framework build phase to determine a dependency?
		let packageTargetDependencies = product
			.baseTarget
			.dependencies
			.filter { $0.targetGUID.starts(with: targetToken) }
			.filter { $0.targetGUID.dropFirst(targetToken.count) == productName }

		precondition(packageTargetDependencies.count == 1, "Expecting one matching package target - found \(packageTargetDependencies.count): \(packageTargetDependencies). Returning first match")

		return packageTargetDependencies.first?.targetGUID ?? packageGUID
	}

	func dependencies(for value: Target) -> [Target] {
		// Direct dependencies
		let dependencyTargetGUIDs = value
			.baseTarget
			.dependencies
			.map { $0.targetGUID }
			.map { resolveSwiftPackage($0) }

		// Framework build phase dependencies
		let frameworkBuildPhases = value
			.baseTarget
			.buildPhases
			.compactMap { $0 as? PIF.FrameworksBuildPhase }

		let frameworkGUIDs = frameworkBuildPhases
			.flatMap { $0.buildFiles }
			.compactMap {
				switch $0.reference {
				case .file(let guid): return guid
				case .target: return nil // TODO: is this fine? I think so since we're looking for .framework file references here not targets which should be a dependency
				}
			}
			.compactMap { cache.frameworks[$0]?.guid }

		let dependencyTargets = (dependencyTargetGUIDs + frameworkGUIDs).compactMap { guidToTargets[$0] }

		return dependencyTargets
	}
}
