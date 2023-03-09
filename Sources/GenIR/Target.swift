//
//  Target.swift
//  
//
//  Created by Thomas Hedderwick on 28/02/2023.
//

import Foundation

struct Target {
	let name: String
	private(set) var commands: [CompilerCommand] = []
	var product: String
	private(set) var dependencies: [String]
}

extension Target: Equatable {
	static func == (lhs: Target, rhs: Target) -> Bool {
		// Unfortunately, matching needs to be on target name
		lhs.name == rhs.name
	}
}
