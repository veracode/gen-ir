//
//  Target.swift
//
//
//  Created by Thomas Hedderwick on 28/02/2023.
//

import Foundation
import PIFSupport
import DependencyGraph

struct TargetKey: Hashable {
	let projectName: String
	let targetName: String
}

/// Represents a product to build (app, framework, plugin, package). It contains the identifying
/// information about a target and its output when it is built or archived. In the future the
/// `PIF` package will likely be modified so that it is usable within the context of Gen-IR
/// directly.
class Target {
	/// Target identifier.
	let guid: String
	/// Name of the target.
	let name: String
	/// Name of the project that the target belongs to.
	let projectName: String
	/// The product name refers to the output of this target when it is built or copied into an archive.
	let productName: String

	/// Returns true if this target is buildable. For packages we only use the `PACKAGE-TARGET`
	/// for the object file, since this is used by the other targets.
	let isBuildable: Bool

	/// Returns true if this target is a test bundle. These will be ignored when packaging bitcode
	/// in order to reduce archive size.
	let isTest: Bool

	/// Returns true if this target produces a package product that will be included in the archive.
	/// For simplicity we say this can be anything that is not a `PACKAGE-TARGET`, which will just be
	/// an object file. The `dynamicTargetVariantGuid` of a `PACKAGE-TARGET` is technically a framework,
	/// but we are using the `PACKAGE-PRODUCT` for that, which depends on it.
	let isPackageProduct: Bool

	let isSwiftPackage: Bool

	init(from baseTarget: PIF.BaseTarget, in project: PIF.Project) {
		guid = baseTarget.guid
		name = baseTarget.name
		// Each target is associated with a project, but the name of the project is not
		// always available. We fallback to the GUID to maintain uniqueness of the target,
		// but this isn't useful for finding the target in the build log, since only
		// the project name is present in there.
		projectName = project.projectName ?? project.groupTree.name ?? project.guid
		if let target = baseTarget as? PIF.Target, !target.productName.isEmpty {
			productName = target.productName
		} else if baseTarget.guid == "PACKAGE-PRODUCT:\(baseTarget.name)" {
			// The `PACKAGE-PRODUCT` for a package does not have a product reference name so
			// we do not have a proper extension. For now we assume it is a framework and add
			// the extension. A better way may be to follow the `dynamicTargetVariantGuid` of
			// the `PACKAGE-TARGET` as this appears to provide the correct name if available.
			productName = baseTarget.name.appending(".framework")
		} else {
			// Fallback to the target's name if we are unable to determine a proper product name.
			productName = baseTarget.name
		}

		if let target = baseTarget as? PIF.Target {
			isTest = target.productType == .unitTest || target.productType == .uiTesting
		} else {
			isTest = false
		}

		isBuildable = guid == "PACKAGE-TARGET:\(name)" || !guid.hasPrefix("PACKAGE-")
		isPackageProduct = !guid.hasPrefix("PACKAGE-TARGET:")
		isSwiftPackage = guid.hasPrefix("PACKAGE-")
	}
}

extension Target: NodeValue {
	var value: Self { self }
	var valueName: String { productName }
}

extension Target: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(ObjectIdentifier(self))
	}

	static func == (lhs: Target, rhs: Target) -> Bool {
		ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
	}
}
