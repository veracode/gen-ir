import Foundation
import Logging

/// Global logger for the module
var logger: Logger!

/// PIFCacheParser is responsible for discovering the files in a PIF Cache and decoding them.
public class PIFCacheParser {
	/// The path to the PIF Cache (in Xcode's DerivedData this is often under Build/Intermediates.noindex/XCBuildData/PIFCache)
	private let cachePath: URL
	/// The most recent workspace in the cache
	public let workspace: PIF.Workspace

	public enum Error: Swift.Error {
		/// A PIF Workspace was not found in the cache
		case workspaceNotFound
	}

	/// Creates an instance initialized with the cache data at the given path.
	public init(cachePath: URL, logger log: Logger) throws {
		logger = log
		self.cachePath = cachePath

		let data = try Data(contentsOf: try Self.workspacePath(in: cachePath))
		workspace = try PIF.PIFDecoder(cache: cachePath).decode(PIF.Workspace.self, from: data)
	}

	/// Finds the most recent workspace in the cache
	/// - Throws: a `workspaceNotFound` error when a workspace is not found
	/// - Returns: the path to the most recent workspace file
	private static func workspacePath(in cachePath: URL) throws -> URL {
		let workspaces = try FileManager.default.contentsOfDirectory(
			at: cachePath.appendingPathComponent("workspace"),
			includingPropertiesForKeys: nil
		)
		.filter { $0.lastPathComponent.starts(with: "WORKSPACE@") }
		.map {
			(
				workspace: $0,
				modificationDate: (try? FileManager.default.attributesOfItem(atPath: $0.path)[.modificationDate] as? Date) ?? Date()
			)
		}

		if workspaces.isEmpty {
			throw Error.workspaceNotFound
		} else if workspaces.count == 1, let workspace = workspaces.first?.workspace {
			return workspace
		}

		// If multiple workspaces exist, it's because the something in the project changed between builds. Sort workspaces by the most recent.
		return workspaces
			.sorted(using: KeyPathComparator(\.modificationDate))
			.first!
			.workspace
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
