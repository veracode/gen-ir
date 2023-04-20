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

	func target(for key: String) -> PBXNativeTarget? {
		if let target = targets.filter({ $0.name == key }).first {
			return target
		} else if let target = targets.filter({ $0.productName == key }).first {
			return target
		}

		return nil
	}

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

	/// Gets the 'path' (normally the name of the target's product) for a given target
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
