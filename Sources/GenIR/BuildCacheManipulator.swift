import Foundation
import LogHandlers

/// Manipulates the build cache, if and when needed, to fix up potential invalidations
struct BuildCacheManipulator {
	/// Path to the build cache
	private let buildCachePath: URL

	/// Build settings used as part of the build
	private let buildSettings: [String: String]

	/// Run without doing any cache manipulation
	private let dryRun: Bool

	/// Should we run the SKIP_INSTALL hack?
	private let shouldDeploySkipInstallHack: Bool

	/// Path to the built products inside the xcarchive
	private let buildProductsPath: URL

	enum Error: Swift.Error {
		case directoryNotFound(String)
		case tooManyDirectories(String)
	}

	/// Creates an instance of the cache manipulator
	/// - Parameters:
	///   - buildCachePath: the build cache to operate on
	///   - buildSettings: the project build settings
	///   - archive: the path to the xcarchive produced as part of the build
	///   - dryRun: should be a dry run?
	init(buildCachePath: URL, buildSettings: [String: String], archive: URL, dryRun: Bool) throws {
		self.buildCachePath = buildCachePath
		self.buildSettings = buildSettings
		self.dryRun = dryRun
		buildProductsPath = archive
		shouldDeploySkipInstallHack = self.buildSettings["SKIP_INSTALL"] == "NO"

		if !self.dryRun {
			guard FileManager.default.directoryExists(at: buildCachePath) else {
				throw Error.directoryNotFound("Build cache path doesn't exist at expected path: \(buildCachePath)")
			}
		}
	}

	/// Start the build cache manipulator
	func manipulate() throws {
		guard !dryRun else { return }

		if shouldDeploySkipInstallHack {
			let intermediatesPath = buildCachePath
			.appendingPathComponent("Build")
			.appendingPathComponent("Intermediates.noindex")
			.appendingPathComponent("ArchiveIntermediates")

			var intermediateFolders: [URL]

			do {
				intermediateFolders = try FileManager.default.directories(at: intermediatesPath, recursive: false)
			} catch {
				throw Error.directoryNotFound(
					"No directories found at \(intermediatesPath), expected exactly one. Ensure you did an archive build."
				)
			}

			// TODO: Can we determine the main target being built here (via scheme or something similar?).
			// That way we don't require a cleaned derived data
			guard intermediateFolders.count == 1 else {
				throw Error.tooManyDirectories(
					"""
					Expected exactly one target folder at path: \(intermediatesPath), but found: \(intermediateFolders).
					Please manually clear your derived data before rebuilding.
					"""
				)
			}

			let intermediatesBuildPath = intermediatesPath
					.appendingPathComponent(intermediateFolders.first!.lastPathComponent)
					.appendingPathComponent("BuildProductsPath")

			guard
				let archivePath = findConfigurationDirectory(intermediatesBuildPath)
			else {
				throw Error.directoryNotFound(
					"Couldn't find or determine a build configuration directory (expected inside of: \(intermediatesBuildPath))"
					)
			}

			try skipInstallHack(archivePath)
		}
	}

	/// This is a hack. Turn away now.
	///
	/// When archiving frameworks with the SKIP_INSTALL=NO setting, frameworks will be evicted (see below) from the build cache.
	/// This means when we rerun commands to generate IR, the frameworks no longer exist on disk, and we fail with linker errors.
	///
	/// This is how the build cache is (roughly) laid out:
	///
	/// * Build/Intermediates.noindex/ArchiveIntermediates/<TARGET>/BuildProductsPath/<CONFIGURATION>-<PLATFORM>
	/// 	* this contains a set of symlinks to elsewhere in the build cache. These links remain in place, but the items they point to are removed
	///
	/// The idea here is simple, attempt to update the symlinks so they point to valid framework product.
	///
	/// - Parameter archiveBuildProductsPath: build products path (see description)
	private func skipInstallHack(_ archiveBuildProductsPath: URL) throws {
		let symlinksToUpdate = FileManager.default.filteredContents(of: archiveBuildProductsPath) {
			$0.lastPathComponent.hasSuffix("framework")
		}
		.reduce(into: [String: URL]()) { $0[$1.lastPathComponent] = $1 }

		let existingFrameworks = FileManager.default.filteredContents(of: buildProductsPath) {
			$0.lastPathComponent.hasSuffix("framework")
		}
		.reduce(into: [String: URL]()) { $0[$1.lastPathComponent] = $1 }

		GenIRLogger.logger.debug("symlinks to update: \(symlinksToUpdate)")
		GenIRLogger.logger.debug("existing frameworks: \(existingFrameworks)")

		try symlinksToUpdate.forEach { name, path in
			guard let buildProductPath = existingFrameworks[name] else {
				GenIRLogger.logger.error("Couldn't lookup \(name) in existing frameworks: \(existingFrameworks.keys)")
				return
			}

			// Update the symlink
			if !(try FileManager.default.destinationOfSymlinkExists(at: path)) {
				try FileManager.default.removeItem(at: path)
				try FileManager.default.createSymbolicLink(at: path, withDestinationURL: buildProductPath)
			}
		}
	}

	/// TODO: This could be more sensible and get the build configuration from the log and match that to a configuration in the PIF Cache
	///  Tries to find the xcode build configuration directory path inside the given path
	/// - Parameter path: the path to search
	/// - Returns: the path to the build configuration directory, if found
	private func findConfigurationDirectory(_ path: URL) -> URL? {
		let folders = (try? FileManager.default.directories(at: path, recursive: false)) ?? []

		guard folders.count != 0 else {
			return nil
		}

		if folders.count == 1 {
			return folders.first
		}

		// Uh oh, there shouldn't be more than one folder here - was a clean performed?
		GenIRLogger.logger.warning(
			"Expected one folder at path: \(path), but got \(folders.count): \(folders). Attempting to select a Debug or Veracode configuration folder"
		)

		let tokens = ["debug", "veracode"]
		var filtered = [URL]()

		for folder in folders {
			for token in tokens where folder.lastPathComponent.lowercased().contains(token) {
				filtered.append(folder)
			}
		}

		if filtered.count > 1 {
			GenIRLogger.logger.error(
				"""
				Found more than one possible folders matching 'debug' or 'veracode' configurations: \(filtered). Please ensure you build from a clean state.
				"""
			)
			return nil
		}

		return filtered.first
	}
}
