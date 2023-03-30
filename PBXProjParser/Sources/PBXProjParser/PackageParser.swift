//
//  PackageParser.swift
//
//
//  Created by Thomas Hedderwick on 22/03/2023.
//

import Foundation
import GenIRExtensions

// SPM imports
import Workspace
import PackageGraph
import TSCBasic
import PackageModel
import Basics

/// Parses SPM packages for a given Xcode Project
struct PackageParser {
	/// Path to the Xcode Project to parse SPM packages for
	private let projectPath: URL
	/// Model of the pbxproj file for this Xcode Project
	private let project: PBXProj

	// private var packages = [XCSwiftPackageProductDependency]()
	private let packageCheckoutPath: URL
	private let localPackagePaths: [URL]
	private let remotePackagePaths: [URL]

	// private let remotePackages: [String: URL]
	// private let packageFiles: [String: URL]

	enum Error: Swift.Error {
		case xcodebuildError(String)
		case swiftPackageError(String)
		case resourceNotFound(String)
	}

	init(projectPath: URL, model: PBXProj) throws {
		self.projectPath = projectPath
		self.project = model

		// Attempt to find a list of local packages - can't use the SPM dependency from pbxproj here as that includes the target name, not the package name
		localPackagePaths = model.objects(of: .fileReference, as: PBXFileReference.self)
			.filter { $0.lastKnownFileType == "wrapper" }
			.map { $0.path }
			.filter { path in
				let packagePath = projectPath
					.deletingLastPathComponent()
					.appendingPath(component: path)
					.appendingPath(component: "Package.swift")
				return FileManager.default.fileExists(atPath: packagePath.filePath)
			}
			.map { $0.fileURL }

		// Attempt to find a list of the remote packages, this involves finding the checkout location in 'derived data'
		// which is two folders up from the build root, and then `SourcePackages/checkout/`
		packageCheckoutPath = try PackageParser.fetchBuildRoot(for: projectPath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
			.appendingPath(component: "SourcePackages", isDirectory: true)
			.appendingPath(component: "checkouts", isDirectory: true)

		remotePackagePaths = try FileManager.default.directories(at: packageCheckoutPath)
			.filter { path in
				FileManager.default.fileExists(atPath: path.appendingPath(component: "Package.swift").filePath)
			}

	/* TODO: Notes
	* SPM Product Deps productName may not align with name of the package. (i.e. SecondLib vs MySecondLibrary)
	.... so we might have to parse every PBXFileReference looking for wrappers that _might_ be SPM packages, as well as
	.... all checkouts in derived data to get all the product names for a given package...
	 Essentially - parse all packages _first_ then determine what's local vs remote if that even matters at that point
	*/
	}

	func parse() async throws {
		let locals = try await localPackagePaths.asyncMap { try await PackageParser.parsePackageFile($0) }
		let remotes = try await remotePackagePaths.asyncMap { try await PackageParser.parsePackageFile($0) }
	}

	private static func parsePackageFile(_ path: URL) async throws -> SwiftPackage? {
		// TODO: Use SPM to parse out the manifest.
		// Needed:
		//   * workspace      -- SwiftTool.getActiveWorkspace()
		//   * root           -- Swifttool.getWorkspaceRoot()
		//   * observability  -- SwiftTool.observabilityScope
		// Then:
		//   * workspace.loadRootManifests()
		let manifests = try await manifests(for: path)
		print(manifests)

		manifests.forEach { (path, manifest) in
			print(manifest.products)
		}

		return nil
	}

	private static func manifests(for path: URL) async throws -> [URL: Manifest] {
		let workspace = try Workspace(forRootPackage: try .init(validating: path.filePath))
		let root = PackageGraphRootInput(packages: [try .init(validating: path.filePath)])
		let observabilityHandler = SPMObservabilityHandler(level: .info)
		let observabilitySystem = ObservabilitySystem(observabilityHandler)
		let observabilityScope = observabilitySystem.topScope

		return try await withCheckedThrowingContinuation { continuation in
			workspace.loadRootManifests(
				packages: root.packages,
				observabilityScope: observabilityScope, // TODO: Double check this....
				//(Result<[AbsolutePath : Manifest], Error>) -> Void
				completion: { result in
					switch result {
					case .success(let manifests):
						let returnValues = manifests.reduce(into: [URL: Manifest]()) { partialResult, pair in
							partialResult[pair.key.pathString.fileURL] = pair.value
						}

						continuation.resume(returning: returnValues)
					case .failure(let error):
						continuation.resume(throwing: error)
					}
				}
			)
		}
	}

	// private func package(for dependency: XCSwiftPackageProductDependency) -> Package? {
	// 	if
	// 		let reference = dependency.package,
	// 		let object = project.object(forKey: reference, as: PBXObject.self),
	// 		object.isa == .remoteSwiftPackageReference
	// 	{
	// 		return remotePackage(for: dependency)
	// 	} else {
	// 		return localPackage(for: dependency)
	// 	}
	// }

	// private func remotePackage(for dependency: XCSwiftPackageProductDependency) -> Package? {
	// 	// Remote packages are a little tricky - we need to get the Package.swift location for them,
	// 	// This normally resides in DerivedData in the products build folder.

	// 	// If we have a dependency named the same as a remote package in the checkout folder, return it
	// 	if let url = remotePackages[dependency.productName] {
	// 		return .init(path: url, type: .remote, reference: dependency)
	// 	}

	// 	// Now it's entirely possible we have a dependency who's name doesn't match a checkout - for example, a package may have one or more targets.
	// 	// In this case, we have to parse the Package.swift for each of these and determine the product names they contain.
	// 	return findPackage(for: dependency)

	// 	// NOTE: We can do this with `swift package dump-package`, capturing the JSON, parsing the following paths: `products[].name`
	// 	// We can then use `targets.name` to match these to targets, and use `targets.dependencies` to get a list of target dependencies
	// }

	// private func findPackage(for dependency: XCSwiftPackageProductDependency) -> Package? {
	// 	if let packageFile = packageFiles[dependency.productName] {
	// 		print("packageFile: \(packageFile)")
	// 	}

	// 	return nil
	// }

	// private func localPackage(for dependency: XCSwiftPackageProductDependency) -> Package? {
	// 	// For local packages, we want to use the `productName` to look up a File Reference with the same name,
	// 	// and get the path for it. This path will be relative to the xcode project we're operating on.
	// 	let paths = project.objects(of: .fileReference, as: PBXFileReference.self)
	// 		.filter { $0.name == dependency.productName }
	// 		.map { $0.path }
	// 		.reduce(into: Set<String>()) { $0.insert($1) }

	// 	if paths.count > 1 {
	// 		logger.warning("Expected 1 unique path for local package (\(dependency.productName)), got \(paths.count). Using \(paths.first!) from \(paths)")
	// 	}

	// 	guard let path = paths.first else {
	// 		logger.error("Didn't find any paths for local package \(dependency.productName). Please report this error.")
	// 		return nil
	// 	}

	// 	return .init(path: projectPath.appendingPath(component: path).absoluteURL, type: .local, reference: dependency)
	// }

	/// Determines the BUILD_ROOT of the project.
	/// - Parameter projectPath: the project to determine the path for
	/// - Returns:
	private static func fetchBuildRoot(for projectPath: URL) throws -> URL {
		let result: Foundation.Process.ReturnValue

		do {
			result = try Process.runShell("/usr/bin/xcodebuild", arguments: ["-showBuildSettings", "-project", projectPath.filePath])
		} catch {
			throw Error.xcodebuildError("xcodebuild process failure: \(error)")
		}

		guard result.code == 0, let stdout = result.stdout else {
			throw Error.xcodebuildError("Failed to run xcodebuild -showBuildSettings for project: \(projectPath). Error: \(result.stdout ?? "nil"), \(result.stderr ?? "nil")")
		}

		// Parse the output looking for BUILD_ROOT, this will give us almost exactly the path that we want
		guard let buildRoot = stdout.split(separator: "\n").first(where: { $0.contains("BUILD_ROOT = ") }) else {
			throw Error.xcodebuildError("Failed to find BUILD_ROOT variable in Xcode Build settings. Output: \(stdout)")
		}

		// Return the path part of the variable
		return buildRoot
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.replacingOccurrences(of: "BUILD_ROOT = ", with: "")
			.fileURL
	}
}

/* Packages come in two variants: remote & local.
	*
	* - Remotes are checked-out into DerivedData where we can find their Package.swift.
	*   - In addition, there's a Package.resolved for _the project_ in the xcodeproj or xcworkspace folders
	*     - `*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
	*     - `*.xcworkspace/xcshareddata/swiftpm/Package.resolved`
	*   - Determining how we can accurately find the derived data path will need to be investigated.
	* - Locals are referenced _only_ by the pbxproj (as far as I can see), and there's no direct link between the XCSwiftPackageProductDependency & the filepath
	*   - However, we could use the product name to look up a PBXFileReference and get the path from there... This is relative to the project file path.
	*/
struct Package {
	enum ReferenceType {
		case local
		case remote
	}

	/// The path **on disk** where the package resides.
	/// For a local reference, this will be anywhere on disk.
	/// For a remote reference, this will be in `DerivedData/<MyBuild>/SourcePackages/checkouts/`
	let path: URL

	/// The type of the package
	let type: ReferenceType

	/// The pbxproj object this package represents
	let reference: XCSwiftPackageProductDependency

	init(path: URL, type: ReferenceType, reference: XCSwiftPackageProductDependency) {
		self.path = path
		self.type = type
		self.reference = reference
	}
}

struct SwiftPackage: Codable {
	let dependencies: [[String: [[String: String]]]]
	let name: String
	let products: [PackageProduct]
}

struct PackageProduct: Codable {
	let name: String
	let targets: [String]
}

public struct SPMObservabilityHandler: ObservabilityHandlerProvider {
	private let handler: SPMOutputHandler

	public var diagnosticsHandler: DiagnosticsHandler { self.handler }

	init(level: Basics.Diagnostic.Severity) {
		handler = .init(logLevel: level, outputStream: TSCBasic.stderrStream)
	}
}

public struct SPMOutputHandler: DiagnosticsHandler {
	public func handleDiagnostic(scope: Basics.ObservabilityScope, diagnostic: Basics.Diagnostic) {
		print("[swiftpm] \(diagnostic.message)")
	}

	init(logLevel: Basics.Diagnostic.Severity, outputStream: ThreadSafeOutputByteStream) {
		// TODO: lol
	}
}
