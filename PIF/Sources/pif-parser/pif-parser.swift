//
//  pif-parser.swift
//
//
//  Created by Thomas Hedderwick on 03/05/2024.
//

import Foundation
import PIFSupport
import Logging

@main
struct PIFCacheParser {
	static func main() throws {
		guard CommandLine.arguments.count == 2 else {
			print("USAGE: \(CommandLine.arguments.first!) [PIFCache path]")
			return
		}

		let cachePath = URL(fileURLWithPath: CommandLine.arguments[1])
		let parser = try PIFSupport.PIFCacheParser(cachePath: cachePath, logger: .init(label: "com.veracode.pif-parser"))
		let workspace = parser.workspace

		print("workspace: \(workspace.guid):")
		print("projects: \(workspace.projects.map { $0.guid }.joined(separator: "\n"))\n")
		print("targets: \(workspace.projects.flatMap { $0.targets }.map { $0.guid }.joined(separator: "\n"))")
	}
}
