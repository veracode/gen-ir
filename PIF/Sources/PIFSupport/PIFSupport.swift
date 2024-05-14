import Foundation
import Logging

var logger: Logger!

public class PIFParser {
	private let cachePath: URL
	public let workspace: PIF.Workspace

	public enum Error: Swift.Error {
		case workspaceNotFound
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

		precondition(workspaces.count == 1, "Encountered more than one workspace - it is expected that a single workspace exists: \(workspaces)")

		guard workspaces.count > 0 else {
			throw Error.workspaceNotFound
		}

		return workspaces[0]
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
