import Foundation
import PIFSupport

class PIFCache {
	public typealias GUID = String

	private let buildCache: URL
	private let pifCachePath: URL
	private let workspace: PIF.Workspace

	enum Error: Swift.Error {
		case nonexistentCache(String)
		case pifError(String)
	}

	init(buildCache: URL) throws {
		self.buildCache = buildCache
		self.pifCachePath = try Self.pifCachePath(in: buildCache)

		do {
			let cache = try PIFParser(cachePath: pifCachePath)
			workspace = cache.workspace
		} catch {
			throw Error.pifError(error.localizedDescription)
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

extension PIF.BaseTarget: NodeValue {
	var valueName: String {
		if let target = self as? PIF.Target, !target.productName.isEmpty {
			return target.productName
		}

		return name
	}
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
	private var guidToTargets: [PIFCache.GUID: Target]

	init(targets: [Target], cache: PIFCache) {
		self.targets = targets
		self.cache = cache

		self.guidToTargets = targets
			.reduce(into: [PIFCache.GUID: Target]()) { partial, target in
				partial[target.baseTarget.guid] = target
			}
	}

	func dependencies(for value: Target) -> [Target] {
		value
			.baseTarget
			.dependencies
			.map { guidToTargets[$0.targetGUID]! }
	}
}
