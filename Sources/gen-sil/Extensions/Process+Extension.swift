//
//  File.swift
//
//
//  Created by Thomas Hedderwick on 04/07/2022.
//

import Foundation

extension Process {
	struct ReturnValue {
		let stdout: String?
		let stderr: String?
		let code: Int32

		var didError: Bool {
			code != 0
		}

		init(stdout: String?, stderr: String?, code: Int32) {
			if let stdout, stdout.isEmpty {
				self.stdout = nil
			} else {
				self.stdout = stdout
			}

			if let stderr, stderr.isEmpty {
				self.stderr = nil
			} else {
				self.stderr = stderr
			}

			self.code = code
		}
	}

	/// Runs a command in a shell returning the stdout
	/// - Parameters:
	///   - command: the command to run
	///   - arguments: the arguments to pass to the command
	///   - environment: the environment variables to set
	/// - Returns: stdout of the command run
	static func runShell(
		_ command: String,
		arguments: [String],
		environment: [String: String] = ProcessInfo.processInfo.environment,
		runInDirectory: URL? = nil
	) throws -> ReturnValue {
		// TODO: change this to get stderr too
		let stdoutPipe = Pipe()
		let stderrPipe = Pipe()
		let process = Process()
		
		if #available(macOS 13.0, *) {
			process.executableURL = URL(filePath: command)
		} else {
			process.launchPath = command
		}

		process.arguments = arguments
		process.standardOutput = stdoutPipe
		process.standardError = stderrPipe
		process.standardInput = FileHandle.nullDevice
		process.environment = environment

		if let runInDirectory {
			process.currentDirectoryURL = runInDirectory
		}
		
		if #available(macOS 10.13, *) {
			try process.run()
		} else {
			process.launch()
		}

		// HACK: Seems NSTask has an issue where the pipe can fill to the point where it doesn't call waitUntilExit...
		// and hangs the process. Workaround that by reading data first before waiting to clear the pipe
		// Thanks to: https://github.com/kareman/SwiftShell/issues/52#issuecomment-365104473 for this
		var stdout = Data()
		var stderr = Data()

		let stdoutHandle = stdoutPipe.fileHandleForReading
		let stderrHandle = stderrPipe.fileHandleForReading
		let group = DispatchGroup()

		DispatchQueue.global().async(group: group) {
			if stdoutHandle.fileDescriptor != stderrHandle.fileDescriptor {
				stderr = stderrHandle.readDataToEndOfFile()
			}
		}

		stdout = stdoutHandle.readDataToEndOfFile()

		process.waitUntilExit()
		group.wait()

		return .init(
			stdout: String(data: stdout, encoding: .utf8),
			stderr: String(data: stderr, encoding: .utf8),
			code: process.terminationStatus
		)
	}
}

