//
//  XcodeProject.swift
//  
//
//  Created by Thomas Hedderwick on 27/01/2023.
//

import Foundation

enum ParsingError: Error {
	case missingKey(String)
	case validationError(String)
}

public struct XcodeProject {
	/// Path to the Workspace
	public let path: URL
	/// The underlying pbxproj model
	private let model: pbxproj

	/// The 'project' object for the pbxproj
	let project: PBXProject
	/// A mapping of target names to their native targets objects
	private(set) var targets: [String: PBXNativeTarget] = [:]
	/// A mapping of package names to their package dependency objects
	private(set) var packages: [String: XCSwiftPackageProductDependency] = [:]
	/// An array of frameworks found in the `Embed Frameworks` build phase
	private(set) var embeddedFrameworks: [String] = []

	public init(path: URL) throws {
		self.path = path
		let pbxprojPath = path.appendingPathComponent("project.pbxproj")
		model = try pbxproj.contentsOf(pbxprojPath)

		project = model.project()

		let nativeTargets: [PBXNativeTarget] = model.objects(for: project.targets)
		targets = nativeTargets.reduce(into: [String: PBXNativeTarget](), { partialResult, target in
			partialResult[self.path(for: target)] = target
		})

		// First pass - get all the direct dependencies
		targets.values.forEach { determineDirectDependencies($0) }

		// Second pass - get all the transitive dependencies
		targets.values.forEach { determineTransitiveDependencies($0) }

		targets.forEach { (name, target) in
			logger.debug("target: \(name). Dependencies: \(target.targetDependencies.map { $0.1.name })")
		}

		packages = model.objects(of: .swiftPackageProductDependecy, as: XCSwiftPackageProductDependency.self)
			.reduce(into: [String: XCSwiftPackageProductDependency](), { partialResult, package in
				partialResult[package.productName] = package
			})

		embeddedFrameworks = model.objects(of: .copyFilesBuildPhase, as: PBXCopyFilesBuildPhase.self)
			.flatMap { $0.files }
			.compactMap { model.object(forKey: $0, as: PBXBuildFile.self) }
			.compactMap { $0.fileRef }
			.compactMap { model.object(forKey: $0, as: PBXFileReference.self) }
			.filter { $0.explicitFileType == "wrapper.framework" || $0.path.hasSuffix(".framework") }
			.map { $0.path }
	}

	private func determineDirectDependencies(_ target: PBXNativeTarget) {
		// Calculate the native target depenedencies
		target.dependencies
			.compactMap { model.object(forKey: $0, as: PBXTargetDependency.self) }
			.compactMap { model.object(forKey: $0.target, as: PBXNativeTarget.self) }
			.forEach { target.add(dependency: .native($0)) }

		// Calculate the swift package dependencies
		target.packageProductDependencies
			.compactMap { model.object(forKey: $0, as: XCSwiftPackageProductDependency.self) } // productName contains the name of the product...
			.forEach { target.add(dependency: .package($0)) }
	}

	private func determineTransitiveDependencies(_ target: PBXNativeTarget) {
		logger.debug("Target: \(target.name). Deps: \(target.targetDependencies.map { $0.0 })")

		var targetDependencies = target.targetDependencies.map { $0.1 }
		var seen = Set<String>()
		var count = 50 // recursion guard

		while !targetDependencies.isEmpty, count != 0 {
			let dependency = targetDependencies.removeFirst()
			count -= 1

			if seen.contains(dependency.name) {
				continue
			}

			seen.insert(dependency.name)

			if case .native(let native) = dependency {
				logger.debug("Adding native dependency: \(dependency.name), deps: \(native.targetDependencies.map { $0.0 })")
				targetDependencies.append(contentsOf: native.targetDependencies.map { $0.1 })
				native.targetDependencies.forEach { target.add(dependency: $0.1) }
			} else {
				// Packages don't have a transitive dependency field like native targets do, so we can't find dependency of a dependency from the project file
				logger.debug("Adding package dependency: \(dependency.name)")
				target.add(dependency: dependency)
			}
		}

		logger.debug("--- FINAL ---")
		logger.debug("Target: \(target.name), deps: \(target.targetDependencies.map { $0.0 })")
	}

	/// A mapping of targets to the product path on disk
	func targetsAndProducts() -> [String: String] {
		targets.values.reduce(into: [String: String]()) { partialResult, target in
			partialResult[target.name] = path(for: target)
		}
	}

	/// Forwards call to the underlying model
	func object<T>(for reference: String, as type: T.Type) -> T? {
		model.object(forKey: reference, as: T.self)
	}

	/// Gets the 'path' (normally the name of the target's product) for a given target
	func path(for target: PBXNativeTarget) -> String {
		guard let reference = object(for: target.productReference, as: PBXFileReference.self) else {
			// TODO: Fix me
			fatalError("Fix this later")
		}

		return reference.path
	}
}
