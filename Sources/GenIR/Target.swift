//
//  Target.swift
//
//
//  Created by Thomas Hedderwick on 28/02/2023.
//

import Foundation
import PBXProjParser

struct Target {
	/// The name of the target
	let name: String
	/// The product name of the target, if one exists
	var product: String?
	/// The backing Native Target from the pbxproj, if it exists
	var nativeTarget: PBXNativeTarget?
	/// The backing
	/// A list of CompilerCommands relating to this target
	var commands: [CompilerCommand] = []
	/// A list of dependencies of this Target
	private(set) var dependencies: [String]

	var nameForOutput: String {
		product ?? name
	}
}

extension Target: Equatable {
	static func == (lhs: Target, rhs: Target) -> Bool {
		// Unfortunately, matching needs to be on target name
		lhs.name == rhs.name
	}
}

extension Target: Hashable {}

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