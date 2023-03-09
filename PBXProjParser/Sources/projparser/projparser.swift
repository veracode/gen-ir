//
//  projparser.swift
//  
//
//  Created by Thomas Hedderwick on 24/02/2023.
//

import Foundation
import PBXProjParser

@main
struct ProjParser {
	static func main() throws {
		guard CommandLine.arguments.count == 2 else {
			print("USAGE: \(CommandLine.arguments.first!) [project path]")
			return
		}

		let projectPath = URL(fileURLWithPath: CommandLine.arguments[1])
		_ = try ProjectParser(path: projectPath, logLevel: .debug)
	}
}
