//
//  File.swift
//
//
//  Created by Thomas Hedderwick on 22/08/2022.
//

import Foundation
import Logging

/// An XcodeLogParser extracts targets and their compiler commands from a given Xcode build log
class XcodeLogParser {

	/// The Xcode build log contents
	private let log: [String]

	enum Error: Swift.Error {
		case noCommandsFound(String)
		case noTargetsFound(String)
	}

	/// Inits a XcodeLogParser from the contents of an Xcode build log
	/// - Parameter log: the contents of the build log
	init(log: [String]) {
		self.log = log
	}

	/// Start parsing the build log
	/// - Parameter targets: The global list of targets
	func parse(_ targets: inout Targets) throws {
		parseBuildLog(log, &targets)

		if targets.isEmpty {
			logger.debug("Found no targets in log: \(log)")

			throw Error.noTargetsFound(
				"""
				No targets were parsed from the build log, if there are targets in the log file please report this as a bug
				"""
			)
		}

		if targets.totalCommandCount == 0 {
			logger.debug("Found no commands in log: \(log)")

			throw Error.noCommandsFound(
				"""
				No commands were parsed from the build log, if there are commands in the log file please report this as a bug
				"""
			)
		}
	}

	/// Parses  an array representing the contents of an Xcode build log
	/// - Parameters:
	///   - lines: contents of the Xcode build log lines
	///   - targets: the container to add found targets to
	private func parseBuildLog(_ lines: [String], _ targets: inout Targets) {
		var currentTarget: Target?
		var seenTargets = Set<String>()

		for (index, line) in lines.enumerated() {
			let line = line.trimmingCharacters(in: .whitespacesAndNewlines)

			if let target = target(from: line), currentTarget?.name != target {
				if seenTargets.insert(target).inserted {
					logger.debug("Found target: \(target)")
				}

				if let targetObject = targets.target(for: target) {
					currentTarget = targetObject
				} else {
					currentTarget = .init(name: target)
					targets.insert(target: currentTarget!)
				}
			}

			guard let currentTarget else {
				continue
			}

			guard
				let compilerCommand = compilerCommand(from: line),
				isPartOfCompilerCommand(lines, index)
			else {
				continue
			}

			logger.debug("Found \(compilerCommand.compiler.rawValue) compiler command for target: \(currentTarget.name)")

			currentTarget.commands.append(compilerCommand)
		}
	}

	private func isPartOfCompilerCommand(_ lines: [String], _ index: Int) -> Bool {
		var result = false
		var offset = lines.index(index, offsetBy: -2)

		// Check the line starts with either 'CompileC', 'SwiftDriver', or 'CompileSwiftSources' to ensure we only pick up compilation commands
		while lines.indices.contains(offset) {
			let previousLine = lines[offset].trimmingCharacters(in: .whitespacesAndNewlines)
			offset -= 1

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

		// Ignore preprocessing of assembly files
		if stripped.contains("-x assembler-with-cpp") { return nil }

		if stripped.contains("/swiftc") {
			return .init(command: stripped, compiler: .swiftc)
		} else if stripped.contains("/clang") {
			return .init(command: stripped, compiler: .clang)
		}

		return nil
	}
}
