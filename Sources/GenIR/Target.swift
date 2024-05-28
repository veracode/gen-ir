//
//  Target.swift
//
//
//  Created by Thomas Hedderwick on 28/02/2023.
//

import Foundation
import PIFSupport
import DependencyGraph

/// A Target represents a product to build (app, framework, plugin, package)
class Target {
	/// The name of the target
	var name: String { baseTarget.name }

	/// The product name of the target, if one is available, otherwise the name
	/// This can happen when the product is not directly buildable (such as a package product or aggregate)
	var productName: String {
		if let target = baseTarget as? PIF.Target, !target.productName.isEmpty {
			return target.productName
		}

		return baseTarget.name
	}

	// TODO: we need to handle SPM's insane naming scheme for products here ^ including the potential of a dynamic variant

	/// The `PIF.BaseTarget` structure that backs this target
	let baseTarget: PIF.BaseTarget
	/// The `CompilerCommands` related to building this target
	let commands: [CompilerCommand]

	/// Initializes a target with the given backing target and commands
	/// - Parameters:
	///   - baseTarget: the underlying `PIF.BaseTarget`
	///   - commands: the commands related to this target
	init(baseTarget: PIF.BaseTarget, commands: [CompilerCommand]) {
		self.baseTarget = baseTarget
		self.commands = commands
	}
}

extension Target {
	/// Helper function to map targets and commands to an array of targets
	/// - Parameters:
	///   - targets: the `PIF.BaseTarget`s that will back the new targets
	///   - targetsToCommands: a mapping of target names to the `CompilerCommands` that relate to them
	/// - Returns: the newly created targets
	static func targets(from targets: [PIF.BaseTarget], with targetsToCommands: [String: [CompilerCommand]]) -> [Target] {
		targets
			.map {
				Target(baseTarget: $0, commands: targetsToCommands[$0.name] ?? [])
			}
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
