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

	public init(path: URL, buildTargets: inout[BuildTarget]) throws {
		self.path = path
        logger.info("Parsing Project: \(path)")
		model = try PBXProj.contentsOf(path.appendingPathComponent("project.pbxproj"))
		project = try model.project()

		/* 
		 * direct build targets of this project
		 */

		// need to start with this list and work through the IDs to get the name and type
		targets = model.objects(for: project.targets)
			.filter {
				// Cocoapods likes to insert resource bundles as native targets. On iOS resource bundles
				// cannot contain executables, therefore we should ignore them - IR will never be generated for them.
				$0.productType != "com.apple.product-type.bundle"
			}

		// list of FileRefs, for matching to target.productReference
		let fileRefs: [PBXFileReference] = model.objects(of: .fileReference, as: PBXFileReference.self )

		// create a buildTarget for every target we find
		logger.info("Processing direct Targets...")
		for target in targets {
			logger.debug("Processing target: \(target.name), refID: \( (target.reference)!)")
 
			// get the File Reference
			let fileRef = fileRefs.filter({ $0.reference == target.productReference})[0]

			// create BuildTarget and save in the master array
			logger.debug("Adding build target \(target.name) of type \( (target.productType)! )")
			let bt: BuildTarget = BuildTarget(name:target.name, productName:target.productName!, fileRef:fileRef)
			buildTargets.append(bt)
		}

		/* 
		 * project references of this project
		 * 	(these will lead to parsing other project files)
		 */
		logger.info("Processing project references...")
		let projRefs = project.projectReferences
		if projRefs != nil {
			logger.info("Found project references")

			for ref in projRefs! {
				logger.debug("Handling project reference \(ref)")
				let pr = ref["ProjectRef"]!

				// get the File Reference
				let fileRef = fileRefs.filter({ $0.reference == pr})[0]
				// check fileRef.lastKnownFileType == "wrapper.pb-project"??

				//logger.debug("Processing project ref: \( (fileRef.name as String?)! ) at \(fileRef.path)")
				logger.debug("Processing project ref: \( (fileRef.name)! ) at \(fileRef.path)")
				// paths are relative to the dir with the .xcodeproj file
				let refPath = path.appendingPathComponent("..").appendingPathComponent(fileRef.path)

				// And, now we recurse...
				try _ = XcodeProject(path: refPath, buildTargets: &buildTargets)
			}
		} else {
			logger.info("No project references found")
		}


		







		packages = model.objects(of: .swiftPackageProductDependency, as: XCSwiftPackageProductDependency.self)





		/*
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
		*/
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
	}

	/// Determines transitive dependencies by looping through direct dependencies and finding the items they depend on
	/// - Parameter target: the target to find transitive dependencies for
	private func determineTransitiveDependencies(_ target: PBXNativeTarget) {
		logger.debug("Target: \(target.name). Direct Deps: \(target.targetDependencies.map { $0.0 })")

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
		logger.debug("Target: \(target.name), All Deps: \(target.targetDependencies.map { $0.0 })")
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
