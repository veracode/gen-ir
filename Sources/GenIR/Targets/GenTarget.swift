//
//  Target.swift
//
//
//  Created by Kevin Rise on 23/10/2023.
//

// TODO: this should probably get merged with the Target class

import Foundation
import struct PBXProjParser.BuildTarget

public struct GenTarget {
	let buildTarget: BuildTarget
	var guid: String?
	var compilerInputs = [String]()

	public init(buildTarget: BuildTarget, guid: String?) {
		self.buildTarget = buildTarget
		self.guid = guid
	}

}