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
	private let model: PBXProj

	/// The 'project' object for the pbxproj
	let project: PBXProject

	/// All the native targets in this project
	let allTargets: [PBXNativeTarget]

	/// All the swift packages in this project
	let allPackages: [XCSwiftPackageProductDependency]

	/// A mapping of target names to their native targets objects
	private(set) var targets: [String: PBXNativeTarget] = [:]

	/// A mapping of package names to their package dependency objects
	private(set) var packages: [String: XCSwiftPackageProductDependency] = [:]

	enum Error: Swift.Error {
		case invalidPBXProj(String)
	}

	public init(path: URL) throws {
		self.path = path
		model = try PBXProj.contentsOf(path.appendingPathComponent("project.pbxproj"))
		project = try model.project()

		allTargets = model.objects(for: project.targets)
		allPackages = model.objects(for: project.packageReferences)

		for target in allTargets {
			// Cocoapods likes to insert resource bundles as native targets. On iOS resource bundles
			// cannot contain executables, therefore we should ignore them - IR will never be generated for them.
			guard target.productType != "com.apple.product-type.bundle" else {
				logger.debug("Skipping bundle target: \(target.name)")
				continue
			}

			targets[target.name] = target

			if let productName = target.productName {
				targets[productName] = target
			}

		// TODO: For now, this is fine - but really we should centralize all this target naming stuff into `Target`
			if let path = self.path(for: target, removeExtension: true) {
					if targets[path] != nil {
						if target.name != path || target.productName != path {
							logger.debug("Clash in path name (\(path)) for target: \(target.name).")
						}
					} else {
						targets[path] = target
					}
				}
		}

		// First pass - get all the direct dependencies
		allTargets.forEach { determineDirectDependencies($0) }

		// Second pass - get all the transitive dependencies
		allTargets.forEach { determineTransitiveDependencies($0) }

		allTargets.forEach { target in
			logger.debug("target: \(target). Dependencies: \(target.targetDependencies.map { $0.1.name })")
		}

		packages = allPackages
			.reduce(into: [String: XCSwiftPackageProductDependency](), { partialResult, package in
				partialResult[package.productName] = package
			})
	}

	/// Determines the target & swift package dependencies for a target
	/// - Parameter target: the target to get direct dependencies for
	private func determineDirectDependencies(_ target: PBXNativeTarget) {
		// Calculate the native target depenedencies
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

	/// A mapping of targets to the product path on disk
	func targetsAndProducts() -> [String: String] {
		var targetsAndProducts = targets.values.reduce(into: [String: String]()) { partialResult, target in
			logger.debug("target: \(target.name)")
			partialResult[target.name] = path(for: target)
		}

		let packagesAndProducts = packages.values.reduce(into: [String: String]()) { partialResult, dependency in
			logger.debug("package: \(dependency.productName)")
			partialResult[dependency.productName] = dependency.productName
		}

		targetsAndProducts.merge(packagesAndProducts) { current, _ in
			current
		}

		return targetsAndProducts
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
