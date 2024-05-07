import Foundation

public class PIFParser {
	private let cachePath: URL

	public enum Error: Swift.Error {
		case workspaceNotFound
	}

	public init(cachePath: URL) {
		self.cachePath = cachePath
	}

	public func parse() throws -> PIF.Workspace {
		let workspace = try workspacePath()
		let data = try Data(contentsOf: workspace)

		return try PIF.PIFDecoder(cache: cachePath).decode(PIF.Workspace.self, from: data)
	}

	private func workspacePath() throws -> URL {
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
