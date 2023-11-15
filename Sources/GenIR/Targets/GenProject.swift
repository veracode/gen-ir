//
//  GenProject.swift
//
//
//  Created by Kevin Rise on 13/11/2023.
//

import Foundation

public struct GenProject {
	//let buildTarget: BuildTarget
	var name: String
	var guid: String
	var filename: String

	var targets: [GenTarget]?
	
	public init(name: String, guid: String, filename: String) {
		self.name = name
		self.guid = guid
		self.filename = filename
	}

	public func addTarget(/*target: GenTarget*/) {
		//self.targets.append(target)
	}

}