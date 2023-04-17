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
	var productName: String?

	enum BackingTarget: Hashable {
		/// The Native Target this Target represents
		case native(PBXNativeTarget)

		/// The Swift Dependency this Target represents
		case spmProductDependency(XCSwiftPackageProductDependency)
	}

	/// The backing object this Target represents
	var backingTarget: BackingTarget?

	/// A list of CompilerCommands relating to this target
	var commands: [CompilerCommand] = []

	// TODO: Remove
	/// A list of dependencies of this Target
	private(set) var dependencies: [String] = []

	/// The name to use when writing IR to disk, prefer the product name if possible.
	var nameForOutput: String {
		productName ?? name
	}

	init(
		name: String,
		productName: String? = nil,
		backingTarget: BackingTarget? = nil,
		commands: [CompilerCommand] = [],
		dependencies: [String] = []
	) {
		self.name = name
		self.productName = productName
		self.backingTarget = backingTarget
		self.commands = commands
		self.dependencies = dependencies
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

extension PBXNativeTarget: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(isa)
		hasher.combine(reference)
		hasher.combine(productName)
		hasher.combine(name)
		hasher.combine(dependencies)
	}
}

extension PBXNativeTarget: Equatable {
	public static func == (lhs: PBXNativeTarget, rhs: PBXNativeTarget) -> Bool {
		// This should be enough as references _should_ be unique to the object
		lhs.reference == rhs.reference
	}
}

extension XCSwiftPackageProductDependency: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(isa)
		hasher.combine(reference)
		hasher.combine(package)
		hasher.combine(productName)
	}
}

extension XCSwiftPackageProductDependency: Equatable {
	public static func == (lhs: XCSwiftPackageProductDependency, rhs: XCSwiftPackageProductDependency) -> Bool {
		lhs.reference == rhs.reference &&
		lhs.package == rhs.package &&
		lhs.productName == rhs.productName
	}
}
