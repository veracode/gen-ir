//
//  GenProject.swift
//
//
//  Created by Kevin Rise on 13/11/2023.
//

import Foundation

public struct GenProject {
	var guid: String
	var filename: URL
	var name: String
	var targets: [GenTarget]?
	
	public init(guid: String, filename: URL, name: String) {
		self.guid = guid
		self.filename = filename
		self.name = name
		//self.targets = targets

	}

	public func addTarget(/*target: GenTarget*/) {
		//self.targets.append(target)
	}

}