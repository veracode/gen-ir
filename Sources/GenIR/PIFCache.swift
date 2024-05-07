import Foundation
import PIFSupport

struct PIFCache {
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
}
