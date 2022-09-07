//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 27/07/2022.
//

import Foundation

struct XcodeRunner: Runner {
	private let config: XcodeConfiguration
	private let coordinator = XcodeCoordinator()

	init(configuration: XcodeConfiguration) throws {
		config = configuration
	}

	public func run() throws {
		print("Running XcodeRunner")
		// we now want to skip any new invocations of this tool
		var environment = ProcessInfo.processInfo.environment
		environment["SHOULD_SKIP_GEN_SIL"] = "1"
		print("running xcodebuild from gen_sil")

		let coordinator = XcodeCoordinator()

		guard let archiveOutput = try coordinator.archive(with: config, environment: environment) else {
			print("Failed to get output from xcodebuild archive command")
			exit(EXIT_FAILURE)
		}

		// TODO: is this ever different from the target in the environment? If not, get rid of this
		guard let target = try coordinator.parseTarget(from: archiveOutput) else {
			print("Failed to find target from output: ")
			archiveOutput.split(separator: "\n").forEach { print($0) }
			exit(EXIT_FAILURE)
		}

		print("Found target: \(target)")

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
				if let result = try coordinator.emit(.ir, for: sourceFile, target: target, config: config) {
					print("result: \(result)")
				}
			} catch {
				print("Failed to emit for file: \(sourceFile), error: \(error)")
			}
		}
	}
}
