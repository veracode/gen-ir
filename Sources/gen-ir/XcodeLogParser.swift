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
	var command: String
	var compiler: Compiler
}

/// Parses an Xcode build log to extract compiler commands used in the build
struct XcodeLogParser {
	/// The commands found in the Xcode build log
	private(set) var commands: [CompilerCommand] = []

	/// The Xcode build log contents
	private let log: [String]

	private let logger: Logger

	enum Error: Swift.Error {
		case noCommandsFound(String)
	}

	// MARK: - Initializers

	/// Inits an XcodeLogParser from an Xcode build log file
	/// - Parameter path: the path to the Xcode build log file
	init(path: URL, logger: Logger) throws {
		self.log = try String(contentsOf: path).components(separatedBy: .newlines)
		self.logger = logger
		self.commands = extractCompilerCommands(log)

		if commands.isEmpty {
			throw Error.noCommandsFound(
				"""
				No commands were parsed from the build log, \
				if there are compiler commands in this log file please report this as a bug
				"""
			)
		}
	}

	/// Creates an XcodeLogParser from the contents of an Xcode build log
	/// - Parameter log: the contents of the build log
	init(log: [String], logger: Logger) throws {
		self.log = log
		self.logger = logger
		self.commands = extractCompilerCommands(log)

		if commands.isEmpty {
			throw Error.noCommandsFound(
				"""
				No commands were parsed from the build log, \
				if there are compiler commands in this log file please report this as a bug
				"""
			)
		}
	}

	// MARK: - Functions

	/// Extracts compiler commands from an array representing the contents of an Xcode build log
	/// - Parameter lines: contents of the Xcode build log lines
	/// - Returns: list of commands and the compiler type used to generate them
	private func extractCompilerCommands(_ lines: [String]) -> [CompilerCommand] {
		return lines.compactMap {
			var stripped = $0.trimmingCharacters(in: .whitespacesAndNewlines)
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
}
