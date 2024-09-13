//
//  File.swift
//
//
//  Created by Thomas Hedderwick on 22/08/2022.
//

import Foundation
import LogHandlers

/// An XcodeLogParser extracts targets and their compiler commands from a given Xcode build log
class XcodeLogParser {
	/// The Xcode build log contents
	private let log: [String]
	/// The current line offset in the log
	private var offset: Int = 0
	/// Any CLI settings found in the build log
	private(set) var settings: [String: String] = [:]
	/// The path to the Xcode build cache
	private(set) var buildCachePath: URL!
	/// A mapping of target names to the compiler commands that relate to them
	private(set) var targetCommands: [String: [CompilerCommand]] = [:]

	enum Error: Swift.Error {
		case noCommandsFound(String)
		case noTargetsFound(String)
		case noBuildCachePathFound(String)
	}

	/// Inits a XcodeLogParser from the contents of an Xcode build log
	/// - Parameter log: the contents of the build log
	init(log: [String]) {
		self.log = log
	}

	/// Start parsing the build log
	func parse() throws {
		parseBuildLog()

		if targetCommands.isEmpty {
			logger.debug("Found no targets in log")

			throw Error.noTargetsFound(
				"""
				No targets were parsed from the build log, if there are targets in the log file please report this as a bug
				"""
			)
		}

		let totalCommandCount = targetCommands
			.values
			.compactMap { $0.count }
			.reduce(0, +)

		if totalCommandCount == 0 {
			logger.debug("Found no commands in log")

			throw Error.noCommandsFound(
				"""
				No commands were parsed from the build log, if there are commands in the log file please report this as a bug
				"""
			)
		}

		if buildCachePath == nil {
			throw Error.noBuildCachePathFound("No build cache was found from the build log. Please report this as a bug.")
		}
	}

	/// Parse the lines from the build log
	func parseBuildLog() {
		var seenTargets = Set<String>()

		while let line = consumeLine() {
			if line.hasPrefix("Build description path: ") {
				buildCachePath = buildDescriptionPath(from: line)
			} else if line.hasPrefix("Build settings from command line:") {
				settings = parseBuildSettings()
			} else {
				// Attempt to find a build task on this line that we are interested in.
				let task = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)[0]

				switch task {
				case "CompileC", "SwiftDriver", "CompileSwiftSources":
					guard let target = target(from: line) else {
						continue
					}

					if seenTargets.insert(target).inserted {
						logger.debug("Found target: \(target)")
					}

					let compilerCommands = parseCompilerCommands()

					compilerCommands.forEach {
						logger.debug("Found \($0.compiler.rawValue) compiler command for target: \(target)")
					}

					targetCommands[target, default: []].append(contentsOf: compilerCommands)
				default:
					continue
				}
			}
		}
	}

	/// Consume the next line from the log file and return it if we have not reached the end
	private func consumeLine() -> String? {
		guard offset + 1 < log.endIndex else { return nil }

		defer { offset += 1 }
		return log[offset]
	}

	/// Parse build settings key-value pairs
	private func parseBuildSettings() -> [String: String] {
		var settings = [String: String]()

		// Build settings end with a blank line
		while let line = consumeLine()?.trimmed(), !line.isEmpty {
			let pair = line.split(separator: "=", maxSplits: 1).map { $0.trimmed() }
			if pair.count < 2 {
				settings[pair[0]] = ""
			} else {
				settings[pair[0]] = pair[1]
			}
		}

		return settings
	}

	/// Parse the build description path from the provided line
	/// - Parameter from: the line that should contain the build description path
	private func buildDescriptionPath(from line: String) -> URL? {
		guard line.hasPrefix("Build description path:"), let startIndex = line.firstIndex(of: ":") else {
			return nil
		}

		var cachePath = String(line[line.index(after: startIndex)..<line.endIndex]).trimmed().fileURL

		if cachePath.pathComponents.contains("DerivedData") {
			// We want the 'project' folder which is the 'Project-randomcrap' folder inside of DerivedData.
			// Build description path is inside this folder, but depending on the build - it can be a variable number of folders up
			while cachePath.deletingLastPathComponent().lastPathComponent != "DerivedData" {
				cachePath.deleteLastPathComponent()
			}
		} else {
			// This build location is outside of the DerivedData directory - we want to go up to the folder _after_ the Build directory
			while cachePath.lastPathComponent != "Build" {
				cachePath.deleteLastPathComponent()
			}

			cachePath.deleteLastPathComponent()
		}

		return cachePath
	}

	/// Parsecompiler commands from the current block
	private func parseCompilerCommands() -> [CompilerCommand] {
		var commands: [CompilerCommand] = []

		while let line = consumeLine() {
			// Assume we have reached the end of this build task's block when we encounter an unindented line.
			guard line.hasPrefix(" ") else {
				break
			}

			guard let compilerCommand = parseCompilerCommand(from: line) else {
				continue
			}

			commands.append(compilerCommand)
		}

		return commands
	}

	/// Parses a `CompilerCommand` from the given line if one exists
	/// - Parameter from: the line which may contain a compiler command
	private func parseCompilerCommand(from line: String) -> CompilerCommand? {
		var commandLine = line

		if let index = line.firstIndexWithEscapes(of: "/"), index != line.startIndex {
			commandLine = String(line[index..<line.endIndex])
		}

		// Ignore preprocessing of assembly files
		if commandLine.contains("-x assembler-with-cpp") {
			return nil
		}

		// Note: the spaces here so we don't match subpaths
		if commandLine.contains("/swiftc ") {
			return .init(command: commandLine, compiler: .swiftc)
		} else if commandLine.contains("/clang ") {
			return .init(command: commandLine, compiler: .clang)
		}

		return nil
	}

	/// Returns the target from the given line
	/// - Parameter line: the line to parse
	/// - Returns: the name of the target if one was found, otherwise nil
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
}
