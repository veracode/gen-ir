//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 27/07/2022.
//

import Foundation

/// The `Runner` for the Xcode subcommand.
///
/// Handles the 'running' logic of command, delegating to coordinators for specific actions
struct XcodeRunner: Runner {
	/// The `Configuration` to use
	private let config: XcodeConfiguration

	/// The coordinator for Xcode build actions
	private let coordinator = XcodeCoordinator()

	/// Initializes an `XcodeRunner` object
	/// - Parameter configuration: the configuration to use when generating artifacts
	init(configuration: XcodeConfiguration) throws {
		config = configuration
	}

	// TODO: Add error handling to this
	/// Attempt to emit the artifacts for an in-xcode run of the tool
	/// - throws:
	public func run() throws {
		print("Running XcodeRunner")

		// we now want to skip any new invocations of this tool
		var environment = ProcessInfo.processInfo.environment
		environment["SHOULD_SKIP_GEN_SIL"] = "1"
		print("running xcodebuild from gen_sil")

		let archiveReturn = try coordinator.archive(with: config, environment: environment)
		guard !archiveReturn.didError, let archiveOutput = archiveReturn.stdout else {
			print("Failed to get output from xcodebuild archive command")
			if let stderr = archiveReturn.stderr {
				print(stderr)
			}
			exit(EXIT_FAILURE)
		}

		guard let target = try coordinator.parseTarget(from: archiveOutput) else {
			print("Failed to find target from output: ")
			archiveOutput.split(separator: "\n").forEach { print($0) }
			exit(EXIT_FAILURE)
		}

		print("Found target: \(target)")

		// TODO: objc support
		guard let sourceFiles = try coordinator.parseSourceFiles(from: archiveOutput) else {
			print("Failed to find source files from output: ")
			archiveOutput.split(separator: "\n").forEach { print($0) }
			exit(EXIT_FAILURE)
		}

		print("------- source files ----------")
		print(sourceFiles)
		print("-------------------------------")

		// emit IR for each source file
		sourceFiles.forEach { sourceFile in
			do {
//				let result = try coordinator.emit(.ir, forFiles: [sourceFile.fileURL], config: config)
//				if let stdout = result.stdout {
//					print("Xcode coordinator result: \(stdout)")
//				}
//
//				if let stderr = result.stderr {
//					print("Xcode Runner emit error: \(stderr)")
//				}
			} catch {
				print("Failed to emit for file: \(sourceFile), error: \(error)")
			}
		}
	}
}
