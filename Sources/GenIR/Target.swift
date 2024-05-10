//
//  Target.swift
//
//
//  Created by Thomas Hedderwick on 28/02/2023.
//

import Foundation
import PBXProjParser
import PIFSupport

class Target {
	var name: String { baseTarget.name }
	var productName: String {
		(baseTarget as? PIF.Target)?.productName ?? baseTarget.name
	}
	// TODO: we need to handle SPM's insane naming scheme for products here ^

	let baseTarget: PIF.BaseTarget
	let commands: [CompilerCommand]

	init(baseTarget: PIF.BaseTarget, commands: [CompilerCommand]) {
		self.baseTarget = baseTarget
		self.commands = commands
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
