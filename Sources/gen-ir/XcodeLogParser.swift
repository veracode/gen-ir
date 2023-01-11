//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 22/08/2022.
//

import Foundation
import Logging

/// An XcodeLogParser extracts targets and their compiler commands from a given Xcode build log
struct XcodeLogParser {
	/// Map of targets and the compiler commands that were part of the target build found in the Xcode build log
	private(set) var targetToCommands: TargetToCommands = [:]
	/// Mapping of target names to product names
	private(set) var targetToProduct: TargetToProduct = [:]

	/// The Xcode build log contents
	private let log: [String]

	enum Error: Swift.Error {
		case noCommandsFound(String)
		case noTargetsFound(String)
	}

	/// Inits a XcodeLogParser from an Xcode build log file
	/// - Parameter path: the path to the Xcode build log file
	init(path: URL) throws {
		self.log = try String(contentsOf: path).components(separatedBy: .newlines)

		let (targetToCommands, targetToProduct) = parseBuildLog(log)
		self.targetToCommands = targetToCommands
		self.targetToProduct = targetToProduct

		try checkTargetAndCommandValidity()
	}

	/// Inits a XcodeLogParser from the contents of an Xcode build log
	/// - Parameter log: the contents of the build log
	init(log: [String]) throws {
		self.log = log

		let (targetToCommands, targetToProduct) = parseBuildLog(log)
		self.targetToCommands = targetToCommands
		self.targetToProduct = targetToProduct

		try checkTargetAndCommandValidity()
	}

	private func checkTargetAndCommandValidity() throws {
		if targetToCommands.keys.isEmpty {
			logger.debug("Found no targets in log: \(log)")

			throw Error.noTargetsFound(
				"""
				No targets were parsed from the build log, if there are targets in the log file please report this as a bug
				"""
			)
		}

		let totalCommands = targetToCommands.map { (target, commands) in
			if commands.isEmpty {
				logger.warning("Found no commands for target: \(target)")
			}

			return commands.count
		}.reduce(0, +)

		if totalCommands == 0 {
			logger.debug("Found no commands in log: \(log)")

			throw Error.noCommandsFound(
				"""
				No commands were parsed from the build log, if there are commands in the log file please report this as a bug
				"""
			)
		}
	}

	/// Parses  an array representing the contents of an Xcode build log
	/// - Parameter lines: contents of the Xcode build log lines
	/// - Returns: A tuple of the targets and their commands, and the targets and their product names
	private func parseBuildLog(_ lines: [String]) -> (TargetToCommands, TargetToProduct) {
		var currentTarget: String?
		var targetToCommands: TargetToCommands = [:]
		var targetToProduct: TargetToProduct = [:]

		for (index, line) in lines.enumerated() {
			let line = line.trimmingCharacters(in: .whitespacesAndNewlines)

			if let target = target(from: line), currentTarget != target {
				logger.debug("Found target: \(target)")
				currentTarget = target
			}

			guard let currentTarget else {
				logger.warning("No target was found for this command - \(line)")
				continue
			}

			if let productName = product(from: line) {
				targetToProduct[currentTarget] = productName
			}

			guard let compilerCommand = compilerCommand(from: line) else {
				continue
			}

			guard isPartOfCompilerCommand(lines, index) else {
				continue
			}

			if targetToCommands[currentTarget] == nil {
				targetToCommands[currentTarget] = []
			}

			logger.debug("Found \(compilerCommand.compiler.rawValue) compiler command")

			targetToCommands[currentTarget]!.append(compilerCommand)
		}

		return (targetToCommands, targetToProduct)
	}

	private func isPartOfCompilerCommand(_ lines: [String], _ index: Int) -> Bool {
		var result = false
		var offset = lines.index(index, offsetBy: -2)

		// Check the line starts with either 'CompileC', 'SwiftDriver', or 'CompileSwiftSources' to ensure we only pick up compilation commands
		while lines.indices.contains(offset) {
			let previousLine = lines[offset].trimmingCharacters(in: .whitespacesAndNewlines)
			offset -= 1

			logger.debug("Looking at previous line: \(previousLine)")

			if previousLine.isEmpty {
				// hit the top of the block, exit loop
				break
			}

			if previousLine.starts(with: "CompileC")
					|| previousLine.starts(with: "SwiftDriver")
					|| previousLine.starts(with: "CompileSwiftSources") {
				result = true
				break
			}
		}

		if !result, lines.indices.contains(lines.index(index, offsetBy: -2)) {
			logger.debug(
			 """
			 Skipping non-compile command block:
			 \(lines[lines.index(index, offsetBy: -2)..<lines.index(after: index)])
			 """
			)
		}

		return result
	}

	private func target(from line: String) -> String? {
		if line.contains("Build target ") {
			var result = line.replacingOccurrences(of: "Build target ", with: "")

			if let bound = result.range(of: "of ")?.lowerBound {
				result = String(result[result.startIndex..<bound])
			} else if let bound = result.range(of: "with configuration ")?.lowerBound {
				result = String(result[result.startIndex..<bound])
			}

			return result.trimmingCharacters(in: .whitespacesAndNewlines)
		} else if let startIndex = line.range(of: "(in target '")?.upperBound, let endIndex = line.range(of: "' from ")?.lowerBound {
			// sometimes (seemingly for archives) build logs follow a different format for targets
			return String(line[startIndex..<endIndex])
		}

		return nil
	}

	private func compilerCommand(from line: String) -> CompilerCommand? {
		var stripped = line
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

	/// Gets a 'product' (app, framework, etc) name from a GenerateDSYM command
	/// This is done in order to correctly line up products with targets of a different name
	private func product(from line: String) -> String? {
		// example line:
		// GenerateDSYMFile /path/to/something.app.dSYM /path/to/something.app (in target 'target' from project 'project')
		guard line.starts(with: "GenerateDSYMFile") else {
			return nil
		}

		let split = line.splitIgnoringEscapes(separator: " ")

		// Second item in the line should be the dSYM path, grab the file name from it
		let suffix = ".dSYM"
		if let dsymPath = split.first(where: { $0.hasSuffix(suffix)}) {
			var productName = String(dsymPath).fileURL.lastPathComponent.dropLast(suffix.count)

			if let dotIndex = productName.lastIndex(of: ".") {
				productName = productName[productName.startIndex..<dotIndex]
			}

			return String(productName)
		} else {
			logger.error("Failed to parse a dSYM path from a GenerateDSYMFile command...")
			assert(true, "Failed to parse a dSYM path from a GenerateDSYMFile command...")
		}

		return nil
	}
}
