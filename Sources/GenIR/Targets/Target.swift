//
//  Target.swift
//
//
//  Created by Thomas Hedderwick on 28/02/2023.
//

import Foundation
import PBXProjParser

class Target {
	/// The name of the target
	let name: String

	/// The product name of the target, if one exists
	var productName: String? {
		switch backingTarget {
		case .native(let target):
			return target.productName
		case .packageDependency(let spm):
			return spm.productName
		default:
			return nil
		}
	}

	enum BackingTarget: Hashable {
		/// The Native Target this Target represents
		case native(PBXNativeTarget)

		/// The Swift Dependency this Target represents
		case packageDependency(XCSwiftPackageProductDependency)
	}

	/// The backing object this Target represents
	var backingTarget: BackingTarget?

	/// A list of CompilerCommands relating to this target
	var commands: [CompilerCommand] = []

	// TODO: Remove
	/// A list of dependencies of this Target
	private(set) var dependencies: [String] = []

	let project: ProjectParser?

	/// The name to use when writing IR to disk, prefer the product name if possible.
	var nameForOutput: String {
		switch backingTarget {
		case .native(let target):
			return path(for: target) ?? productName ?? name
		case .packageDependency, .none:
			return productName ?? name
		}
	}

	/// Gets the path for native targets
	var path: String? {
		switch backingTarget {
		case .native(let target):
			return path(for: target)
		case .packageDependency, .none:
			return nil
		}
	}

	init(
		name: String,
		backingTarget: BackingTarget? = nil,
		commands: [CompilerCommand] = [],
		dependencies: [String] = [],
		project: ProjectParser? = nil
	) {
		self.name = name
		self.backingTarget = backingTarget
		self.commands = commands
		self.dependencies = dependencies
		self.project = project
	}

	/// Gets the 'path' (normally the name of the target's product) for a given target
	private func path(for target: PBXNativeTarget) -> String? {
		guard let model = project?.model(for: target.name) else {
			logger.debug("Failed to get model for target: \(target)")
			return nil
		}

		guard let productReference = target.productReference else {
			logger.debug("Failed to get product reference for target: \(target). Possibly a SPM Package description?")
			return nil
		}

		guard let reference = model.object(forKey: productReference, as: PBXFileReference.self) else {
			logger.error("Failed to get object for target productReference: \(productReference)")
			return nil
		}

		return (reference.path as NSString).lastPathComponent as String
	}
}

// MARK: - Protocol Conformance for Hashable storage
extension Target: Equatable {
	static func == (lhs: Target, rhs: Target) -> Bool {
		lhs.name == rhs.name &&
		lhs.productName == rhs.productName &&
		lhs.backingTarget == rhs.backingTarget &&
		lhs.commands == rhs.commands &&
		lhs.dependencies == rhs.dependencies
	}
}

extension Target: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(name)
		hasher.combine(productName)
		hasher.combine(backingTarget)
	}
}

extension Target: CustomStringConvertible {
	var description: String {
		"""
		Target(name: \(name), product: \(productName ?? "nil"), \
		commands: \(commands.count), backing target: \(String(describing: backingTarget)))
		"""
	}
}