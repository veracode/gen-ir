//
//  Process+Extension.swift
//
//
//  Created by Thomas Hedderwick on 04/07/2022.
//

import Foundation

extension Process {
	/// Presents the result of a Process
	struct ReturnValue {
		/// The stdout output of the process, if there was any
		let stdout: String?
		/// The stderr output of the process, if there was any
		let stderr: String?
		/// The return code of the process
		let code: Int32

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

	/// Runs a command in a shell.
	/// - Parameters:
	///   - command: The command to run
	///   - arguments: The arguments to pass to the command
	///   - environment: The environment variables to run with
	///   - runInDirectory: The directory to execute the process in
	///   - joinPipes: Should stderr be redirected to stdout?
	/// - Returns: A struct with the error code, stdout, and stderr
	static func runShell(
		_ command: String,
		arguments: [String],
		environment: [String: String] = ProcessInfo.processInfo.environment,
		runInDirectory: URL? = nil,
		joinPipes: Bool = false
	) throws -> ReturnValue {
		let stdoutPipe = Pipe()
		let stderrPipe = joinPipes ? stdoutPipe : Pipe()

		let process = Process()

		let executable = command.replacingOccurrences(of: "\\", with: "")

		if #available(macOS 10.13, *) {
			process.executableURL = executable.fileURL
		} else {
			process.launchPath = executable
		}

		process.arguments = arguments.map { $0.replacingOccurrences(of: "\\", with: "") }
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

		// see: https://github.com/apple/swift/issues/57827
		try? stdoutHandle.close()
		try? stderrHandle.close()

		return .init(
			stdout: String(data: stdout, encoding: .utf8),
			stderr: String(data: stderr, encoding: .utf8),
			code: process.terminationStatus
		)
	}
}
