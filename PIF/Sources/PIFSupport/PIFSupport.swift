import Foundation
import Logging

var logger: Logger!

public class PIFParser {
	private let cachePath: URL
	public let workspace: PIF.Workspace

	public enum Error: Swift.Error {
		case workspaceNotFound
		case filesystemError(Swift.Error)
	}

	public init(cachePath: URL, logger log: Logger) throws {
		logger = log
		self.cachePath = cachePath

		let data = try Data(contentsOf: try Self.workspacePath(in: cachePath))
		workspace = try PIF.PIFDecoder(cache: cachePath).decode(PIF.Workspace.self, from: data)
	}

	private static func workspacePath(in cachePath: URL) throws -> URL {
		let path = cachePath.appendingPathComponent("workspace")

		let workspaces = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: [.isRegularFileKey])
			.filter { $0.lastPathComponent.starts(with: "WORKSPACE@") }

		guard !workspaces.isEmpty else {
			throw Error.workspaceNotFound
		}

		if workspaces.count == 1 {
			return workspaces[0]
		}

		// If multiple workspaces exist, it's because the something in the project changed between builds. Sort workspaces by the most recent.
		func modificationDate(_ path: URL) -> Date {
			(try? FileManager.default.attributesOfItem(atPath: path.path)[.modificationDate] as? Date) ?? Date()
		}

		logger.debug("Found multiple workspaces, sorting by modification date and returning most recently modified workspace")

		let workspacesAndDates = workspaces
			.map {
				(modificationDate($0), $0)
			}

		logger.debug("Comparing dates and workspaces: ")
		workspacesAndDates.forEach { logger.debug("\($0) - \($1)") }

		return workspacesAndDates
			.sorted {
				$0.0 > $1.0
			}[0].1
	}
}

extension PIF {
	class PIFDecoder: JSONDecoder {
		internal init(cache path: URL) {
			super.init()

			userInfo[.pifCachePath] = path
		}
	}
}

extension CodingUserInfoKey {
	static let pifCachePath: CodingUserInfoKey = CodingUserInfoKey(rawValue: "PIFCachePath")!
}
