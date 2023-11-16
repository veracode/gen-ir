//
//  ManifestFinder2.swift
//  BuildAnalyzer
//
//  Created by Bartosz Polaczyk on 8/26/23.
//

import Foundation
import XcodeHasher

public struct ManifestFinderOptions {
	let project: URL
	let scheme: String
	let derivedData: URL?

	static func build(project: URL, scheme: String) -> Self {
		ManifestFinderOptions(project: project, scheme: scheme, derivedData: nil)
	}

	func guessProjectName() throws -> String  {
		switch project.lastPathComponent {
		case "Package.swift":
			return try guessPackageProjectName(swiftPackage: project)
		default:
			return project.deletingPathExtension().lastPathComponent
		}
	}

	private func guessPackageProjectName(swiftPackage: URL) throws -> String {
		// heuristic to find a project as the directory name of a Package.swift location
		return swiftPackage.deletingLastPathComponent().lastPathComponent
	}
}

public struct ManifestLocation {
	let projectFile: URL?
	let manifest: URL
	var pifCache: URL?
	let timingDatabase: URL?

	func withProjectFile(_ url: URL) -> Self {
		.init(projectFile: url, manifest: self.manifest, pifCache: self.pifCache, timingDatabase: self.timingDatabase)
	}
}

/// Helper methods to locate Xcode's DD directory and project's content
public struct ManifestFinder {
	//let xcbuildDataDir = "Build/Intermediates.noindex/XCBuildData/"
	let xcbuildArchiveDataDir = "Build/Intermediates.noindex/ArchiveIntermediates/"
	let xcbuildDataDir = "IntermediateBuildFilesPath/XCBuildData"
	let pifCacheDir = "Build/Intermediates.noindex/XCBuildData/PIFCache"

	var defaultDerivedData: URL {
		let homeDirURL = URL.homeDirectory
		return homeDirURL.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
	}

	public init() {}

	public func findLatestManifest(options: ManifestFinderOptions) throws -> ManifestLocation? {
	   let file = options.project
		switch file.pathExtension {
		case "json":
			return .init(projectFile: nil, manifest: file, timingDatabase: nil)
		case "xcbuild" where file.lastPathComponent.hasSuffix("-manifest.xcbuild"):
			return .init(projectFile: nil, manifest: file, timingDatabase: nil)
		case "xcodeproj", "xcworkspace", "swift", "playground":
			// swift for Package.swift approach
			return try findManifestFromProject(options: options)?.withProjectFile(options.project)
		default:
			throw ManifestFinderError.invalidFileFormat(options.project)
		}

	}
	private func findManifestFromProject(options: ManifestFinderOptions) throws -> ManifestLocation? {
		// get project dir
		let projectDir = try getProjectDir(options)

		// manifests are in xcbuild dir
		let xcbuildDir = projectDir
								.appendingPathComponent(xcbuildArchiveDataDir)
								.appendingPathComponent(options.scheme)
								.appendingPathComponent(xcbuildDataDir)

		// TODO: is there a better/cleaner way to do this?
		//return try getLatestManifest(xcbuildDir)
		var manifestLocation: ManifestLocation
		manifestLocation = try getLatestManifest(xcbuildDir)
		manifestLocation.pifCache = projectDir.appendingPathComponent(pifCacheDir)
		return manifestLocation
	}


	private func getProjectDir(_ options: ManifestFinderOptions) throws -> URL {
		// get derivedDataDir
		let derivedDataDir = getDerivedDataDir(options)
		// get project dir
		return try getProjectDir(options: options, derivedData: derivedDataDir)
	}

	private func getDerivedDataDir(_ options: ManifestFinderOptions) -> URL {
		if let explicitDerivedData = options.derivedData {
			return explicitDerivedData
		}

		let projectLocation = options.project.deletingLastPathComponent()
		if let customDerivedDataDir = getCustomDerivedDataDir(relativeTo: projectLocation) {
			return customDerivedDataDir
		}

		return defaultDerivedData
	}

	private func getProjectDir(options: ManifestFinderOptions,
							   derivedData: URL) throws -> URL {
		// when xcodebuild is run with -derivedDataPath or relative path the logs are at the root level
		let projectName = try options.guessProjectName()
		let ddDir = derivedData.appendingPathComponent(projectName)
		if FileManager.default.fileExists(atPath: ddDir.path) {
			return derivedData.appendingPathComponent(projectName)
		}
		// look with project-hash directory
		let folderName = try getProjectFolderNameWithHash(options.project)
		let hashedProjectDir = derivedData.appendingPathComponent(folderName)
		if FileManager.default.fileExists(atPath: hashedProjectDir.path) {
			return hashedProjectDir
		}

		throw ManifestFinderError.projectDictionaryNotFound(lookupLocations: [ddDir, hashedProjectDir])
	}

	private func getCustomDerivedDataDir(relativeTo relative: URL) -> URL? {
		guard let xcodeOptions = UserDefaults.standard.persistentDomain(forName: "com.apple.dt.Xcode") else {
			return nil
		}
		guard let customLocation = xcodeOptions["IDECustomDerivedDataLocation"] as? String else {
			return nil
		}
		return URL(fileURLWithPath: customLocation, relativeTo: relative)
	}


	/// Returns the latest xcactivitylog file path in the given directory
	/// - parameter dir: The full path for the directory
	/// - returns: The path for the latest xcactivitylog file in it.
	/// - throws: An `Error` if the directory doesn't exist or if there are no xcactivitylog files in it.
	public func getLatestManifest(_ dir: URL) throws -> ManifestLocation {
		let fileManager = FileManager.default
		let files = try fileManager.contentsOfDirectory(at: dir,
														includingPropertiesForKeys: [.contentModificationDateKey],
														options: .skipsHiddenFiles)
		// Xcode 15+ uses .xcbuilddata
		// older uses dirs with buildDebugging- prefix or {hash}-manifest.xcbuild
		let sorted = try files.filter {
			$0.path.hasSuffix(".xcbuilddata") ||
			$0.path.hasPrefix("buildDebugging-") ||
			$0.path.hasSuffix("-manifest.xcbuild")
		}.sorted {
			let lhv = try $0.resourceValues(forKeys: [.contentModificationDateKey])
			let rhv = try $1.resourceValues(forKeys: [.contentModificationDateKey])
			guard let lhDate = lhv.contentModificationDate, let rhDate = rhv.contentModificationDate else {
				return false
			}
			return lhDate.compare(rhDate) == .orderedDescending
		}
		guard let xcBuildDataOrManifest = sorted.first else {
			throw ManifestFinderError.manifestNotFound
		}
		// Find manifest.json

		let potentialManifests = [
			xcBuildDataOrManifest,
			xcBuildDataOrManifest.appending(component: "manifest.json"),
			xcBuildDataOrManifest.appending(component: "current-manifest.xcbuild")
			]
		let existingManifests = potentialManifests.filter { url in
			var isDir: ObjCBool = false
			return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
		}
		guard let manifest = existingManifests.first else {
			throw ManifestFinderError.manifestNotFound
		}
		// the "main" .db corresponds to the most recent manifest
		let timingDb = dir.appending(component: "build.db")
		return ManifestLocation(projectFile: nil, manifest: manifest, timingDatabase: timingDb)
	}

	public func getProjectFolderNameWithHash(_ project: URL) throws -> String {
		// require no / at the end
		let path = URL(fileURLWithPath: project.path, isDirectory: false)
		let projectName = path.deletingPathExtension().lastPathComponent
		let hash = try XcodeHasher.hashString(for: path.path)
		return "\(projectName)-\(hash)"
	}

}
