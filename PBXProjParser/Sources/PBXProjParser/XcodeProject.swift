//
//  XcodeProject.swift
//
//
//  Created by Thomas Hedderwick on 27/01/2023.
//

import Foundation

/// Represents an xcodeproj bundle
public struct XcodeProject {
	/// Path to the Workspace
	public let path: URL

	/// The underlying pbxproj model
	public let model: PBXProj

	/// The 'project' object for the pbxproj
	let project: PBXProject

	/// All the native targets in this project
	let targets: [PBXNativeTarget]

	/// All the swift packages in this project
	let packages: [XCSwiftPackageProductDependency]

	enum Error: Swift.Error {
		case invalidPBXProj(String)
	}

	public init(path: URL) throws {
		self.path = path
		model = try PBXProj.contentsOf(path.appendingPathComponent("project.pbxproj"))
		project = try model.project()

		targets = model.objects(for: project.targets)
			.filter {
				// Cocoapods likes to insert resource bundles as native targets. On iOS resource bundles
				// cannot contain executables, therefore we should ignore them - IR will never be generated for them.
				$0.productType != "com.apple.product-type.bundle"
			}

		packages = model.objects(of: .swiftPackageProductDependency, as: XCSwiftPackageProductDependency.self)

		// First pass - get all the direct dependencies
		targets.forEach { determineDirectDependencies($0) }

		// Second pass - get all the transitive dependencies
		targets.forEach { determineTransitiveDependencies($0) }

		targets.forEach { target in
			logger.debug("target: \(target.name). Dependencies: \(target.targetDependencies.map { $0.1.name })")
		}

		packages.forEach { package in
			logger.debug("package: \(package.productName)")
		}
	}

	/// Gets the native target for a given name
	/// - Parameter name: the target name or product name to lookup
	/// - Returns: the native target corresponding to the name provided
	func target(for name: String) -> PBXNativeTarget? {
		if let target = targets.filter({ $0.name == name }).first {
			return target
		} else if let target = targets.filter({ $0.productName == name }).first {
			return target
		}

		return nil
	}

	/// Gets the package dependency object for a given name
	/// - Parameter name: the product name to lookup
	/// - Returns: the swift package product dependency object corresponding to the name provided
	func package(for key: String) -> XCSwiftPackageProductDependency? {
		packages.filter({ $0.productName == key }).first
	}

	/// Determines the target & swift package dependencies for a target
	/// - Parameter target: the target to get direct dependencies for
	private func determineDirectDependencies(_ target: PBXNativeTarget) {
		// Calculate the native target dependencies
		target.dependencies
			.compactMap { model.object(forKey: $0, as: PBXTargetDependency.self) }
			.compactMap { dependency in
				if let target = dependency.target {
					return target
				}

				guard
					let targetProxy = dependency.targetProxy,
					let proxy = model.object(forKey: targetProxy, as: PBXContainerItemProxy.self)
				else {
					return nil
				}

				return proxy.remoteGlobalIDString
			}
			.compactMap { model.object(forKey: $0, as: PBXNativeTarget.self) }
			.forEach { target.add(dependency: .native($0)) }

		// Calculate the swift package dependencies
		target.packageProductDependencies
			.compactMap { model.object(forKey: $0, as: XCSwiftPackageProductDependency.self) }
			.forEach { target.add(dependency: .package($0)) }

		// Calculate the dependencies from "Link Binary with Library" build phase
		let buildFiles = determineBuildPhaseFrameworkDependencies(target, with: model)

		// Now, we have two potential targets - file & package dependencies.
		// File dependencies will likely have a reference in another Xcode Project. We might not have seen said project yet, so we need to offload discovery until after we've parsed all projects...
		// Package dependencies will be a swift package - those we can handle easily :)

		// ONE: package dependencies - they are the easiest
		buildFiles
			.compactMap { $0.productRef }
			.compactMap { model.object(forKey: $0, as: XCSwiftPackageProductDependency.self) }
			.forEach { target.add(dependency: .package($0)) }

		// TWO: Resolve dependencies to... a thing that refers to something in the other project
		let fileReferences = buildFiles
			.compactMap { $0.fileRef }
			.compactMap { model.object(forKey: $0, as: PBXFileReference.self) }

		fileReferences
			.filter { $0.explicitFileType == "wrapper.framework" }
			.compactMap { $0.path } // TODO: do we want to last path component the path here? Need to figure out matching...
			.filter { !$0.contains("System/Library/Frameworks/")} // System frameworks will contain this path
			.forEach { target.add(dependency: .externalProjectFramework($0)) }
	}

	/// Determines transitive dependencies by looping through direct dependencies and finding the items they depend on
	/// - Parameter target: the target to find transitive dependencies for
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

			switch dependency {
			case .native(let nativeTarget):
				logger.debug("Adding native dependency: \(dependency.name), deps: \(nativeTarget.targetDependencies.map { $0.0 })")
				targetDependencies.append(contentsOf: nativeTarget.targetDependencies.map { $0.1 })
				nativeTarget.targetDependencies.forEach { target.add(dependency: $0.1) }
			case .package:
				// Packages don't have a transitive dependency field like native targets do, so we can't find dependency of a dependency from the project file
				logger.debug("Adding package dependency: \(dependency.name)")
				target.add(dependency: dependency)
			case .externalProjectFramework:
				// Can't move IR dependencies for prebuilt frameworks
				continue
			}
		}

		logger.debug("--- FINAL ---")
		logger.debug("Target: \(target.name), deps: \(target.targetDependencies.map { $0.0 })")
	}

	/// Gets the 'path' (normally the name of the target's product) for a given target
	/// - Parameters:
	///   - target: the target to get the path for
	///   - removeExtension: should the file extension be removed from the returned path
	/// - Returns: the path, if one was found
	func path(for target: PBXNativeTarget, removeExtension: Bool = false) -> String? {
		guard let productReference = target.productReference else {
			logger.debug("Failed to get product reference for target: \(target). Possibly a SPM Package description?")
			return nil
		}

		guard let reference = model.object(forKey: productReference, as: PBXFileReference.self) else {
			logger.error("Failed to get object for target productReference: \(productReference)")
			return nil
		}

		var path = ((reference.path as NSString).lastPathComponent as String)

		if removeExtension, let index = path.firstIndex(of: ".") {
			path = String(path[path.startIndex..<index])
		}

		return path
	}
}

private func determineBuildPhaseFrameworkDependencies(_ target: PBXNativeTarget, with model: PBXProj) -> [PBXBuildFile] {
	// Find the 'Link Binary with Libraries' build phase
	let buildPhase = target.buildPhases
		.compactMap { model.object(forKey: $0, as: PBXFrameworksBuildPhase.self) }
		.first

	guard let buildPhase else {
		logger.debug("No PBXFrameworkBuild phase for target: \(target) found, continuing.")
		return []
	}

	return buildPhase.files
		.compactMap { model.object(forKey: $0, as: PBXBuildFile.self) }
}
