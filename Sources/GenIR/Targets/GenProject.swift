//
//  GenProject.swift
//
//
//  Created by Kevin Rise on 13/11/2023.
//

import Foundation

class GenProject {
	var guid: String
	// periphery:ignore - filename can be handy for debugging
	var filename: URL
	var name: String
	var targets: [GenTarget]?

	init(guid: String, filename: URL, name: String) {
		self.guid = guid
		self.filename = filename
		self.name = name
	}

	func addTarget(target: GenTarget) {
		if (self.targets?.append(target)) == nil {
			self.targets = [target]
		}
	}

}
