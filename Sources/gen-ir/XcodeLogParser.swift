//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 22/08/2022.
//

import Foundation
import Logging

enum Compiler: String {
	case clang
	case swiftc
}

struct CompilerCommand {
	let command: String
	let compiler: Compiler
}

typealias TargetsAndCommands = [String: [CompilerCommand]]

/// Parses an Xcode build log to extract compiler commands used in the build
struct XcodeLogParser {
	/// Map of targets and the compiler commands that were part of the target build found in the Xcode build log
	private(set) var targetsAndCommands: TargetsAndCommands = [:]

	/// The Xcode build log contents
	private let log: [String]

	enum Error: Swift.Error {
		case noCommandsFound(String)
		case noTargetsFound(String)
	}

	/// Inits an XcodeLogParser from an Xcode build log file
	/// - Parameter path: the path to the Xcode build log file
	init(path: URL) throws {
		self.log = try String(contentsOf: path).components(separatedBy: .newlines)
		self.targetsAndCommands = extractCompilerCommands(log)

		try checkTargetAndCommandValidity()
	}

	/// Creates an XcodeLogParser from the contents of an Xcode build log
	/// - Parameter log: the contents of the build log
	init(log: [String]) throws {
		self.log = log
		self.targetsAndCommands = extractCompilerCommands(log)

		try checkTargetAndCommandValidity()
	}

	private func checkTargetAndCommandValidity() throws {
		if targetsAndCommands.keys.isEmpty {
			logger.debug("Found no targets in log: \(log)")

			throw Error.noTargetsFound(
				"""
				No targets were parsed from the build log, if there are targets in the log file please report this as a bug
				"""
			)
		}

		targetsAndCommands.forEach { (target, commands) in
			if commands.isEmpty {
				logger.warning("Found no commands for target: \(target)")
			}
		}
	}

	/// Extracts targets and compiler commands from an array representing the contents of an Xcode build log
	/// - Parameter lines: contents of the Xcode build log lines
	/// - Returns: map of targets and the commands the compiler used to generate them
	private func extractCompilerCommands(_ lines: [String]) -> TargetsAndCommands {
		var currentTarget: String?
		var result: TargetsAndCommands = [:]

		for line in lines {
			if let target = getTarget(from: line) {
				logger.debug("Found target: \(target)")
				currentTarget = target
			}

			guard let compilerCommand = getCompilerCommand(from: line) else {
				continue
			}

			guard let currentTarget else {
				logger.warning("No target was found for this command - \(line)")
				continue
			}

			if result[currentTarget] == nil {
				result[currentTarget] = []
			}

			logger.debug("Found \(compilerCommand.compiler.rawValue) compiler command")

			result[currentTarget]!.append(compilerCommand)
		}

		return result
	}

	private func getTarget(from line: String) -> String? {
		guard line.contains("Build target ") else { return nil }

		var result = line.replacingOccurrences(of: "Build target ", with: "")

		if let bound = result.range(of: "of ")?.lowerBound {
			result = String(result[result.startIndex..<bound])
		}

		return result.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private func getCompilerCommand(from line: String) -> CompilerCommand? {
		var stripped = line.trimmingCharacters(in: .whitespacesAndNewlines)

		if let index = stripped.firstIndexWithEscapes(of: "/"), index != stripped.startIndex {
			stripped = String(stripped[index..<stripped.endIndex])
		}

		if stripped.contains("/swiftc") {
			return .init(command: stripped, compiler: .swiftc)
		} else if stripped.contains("/clang") {
			return .init(command: stripped, compiler: .clang)
		}

		return nil
	}
}
