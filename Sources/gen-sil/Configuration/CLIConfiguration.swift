//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 27/07/2022.
//

import Foundation

enum PathType {
	case project(URL)
	case workspace(URL)
}

// TODO: Ensure this doesn't loop if some idiot adds this command to a build phase....
struct CLIConfiguration: Configuration {
	let path: PathType
	let output: URL

	init(_ pathType: PathType, output: URL) {
		path = pathType
		self.output = output
	}
}
