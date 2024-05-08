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

	private lazy var projectsByGUID: [GUID: PIF.Project] = {
		workspace
			.projects
			.reduce(into: [GUID: PIF.Project]()) { result, element in
				result[element.guid] = element
			}
	}()

	func project(for guid: GUID) -> PIF.Project? {
		projectsByGUID[guid]
	}

	// TODO: do we need to handle Aggregate targets here? Probably - investigate and update to BaseTarget if so
	var targets: [PIF.Target] {
		workspace
			.projects
			.flatMap {
				$0
					.targets
					.compactMap { $0 as? PIF.Target }
			}
	}

	private lazy var targetsByGUID: [GUID: PIF.Target] = {
		targets
			.reduce(into: [GUID: PIF.Target]()) { result, element in
				result[element.guid] = element
			}
	}()

	func target(for guid: GUID) -> PIF.Target? {
		targetsByGUID[guid]
	}
}
