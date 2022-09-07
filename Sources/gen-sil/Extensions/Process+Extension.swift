//
//  File.swift
//
//
//  Created by Thomas Hedderwick on 04/07/2022.
//

import Foundation

extension Process {
	/// Runs a command in a shell returning the stdout
	/// - Parameters:
	///   - command: the command to run
	///   - arguments: the arguments to pass to the command
	///   - environment: the environment variables to set
	/// - Returns: stdout of the command run
	static func runShell(
		_ command: String,
		arguments: [String],
		environment: [String: String] = ProcessInfo.processInfo.environment
	) throws -> String? {
		let pipe = Pipe()
		let process = Process()
		
		if #available(macOS 13.0, *) {
			process.executableURL = URL(filePath: command)
		} else {
			process.launchPath = command
		}
		process.arguments = arguments
		process.standardOutput = pipe
		process.environment = environment
		
		if #available(macOS 10.13, *) {
			try process.run()
		} else {
			process.launch()
		}
		
		let data: Data
		if #available(macOS 10.15.4, *) {
			data = try pipe.fileHandleForReading.readToEnd() ?? Data()
		} else {
			data = pipe.fileHandleForReading.readDataToEndOfFile()
		}
		
		return String(data: data, encoding: .utf8)
	}
}

