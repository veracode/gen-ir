//
//  File.swift
//
//
//  Created by Thomas Hedderwick on 22/08/2022.
//

import Foundation
import Logging

/// An XcodeLogParser extracts compiler commands from a given Xcode build log and assigns them to build targets
class XcodeLogParser {

	/// The Xcode build log contents
	private let log: [String]

	/// Any CLI Settings found in the build log
	private(set) var settings: [String: String] = [:]

	/// The path to the Xcode build cache
	private(set) var buildCachePath: URL!

	private var projects: [GenProject]

	enum Error: Swift.Error {
		case noBuildCachePathFound(String)
	}

	/// Inits a XcodeLogParser from the contents of an Xcode build log
	/// - Parameter log: the contents of the build log
	init(log: [String], projects: [GenProject]) {
		self.log = log
		self.projects = projects
	}

	/// Start parsing the build log
	func parse() throws {
		parseBuildLog(lines: log)

		if buildCachePath == nil {
			throw Error.noBuildCachePathFound("No build cache was found from the build log. Please report this as a bug.")
		}
	}

	/// Parses  an array representing the contents of an Xcode build log
	/// - Parameters:
	///   - lines: contents of the Xcode build log lines
	private func parseBuildLog(lines: [String]) {
		var currentTarget: GenTarget?
		var currentProject: GenProject?

		logger.info("Parsing build log...")
		for (index, line) in lines.enumerated() {
			let line = line.trimmingCharacters(in: .whitespacesAndNewlines)

			if line.contains("Build settings from command line") {
				// Every line until an empty line will contain a build setting from the CLI arguments
				guard let nextEmptyLine = lines.nextIndex(of: "", after: index) else { continue }

				settings = lines[index.advanced(by: 1)..<nextEmptyLine]
					.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
					.map { $0.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines)} }
					.filter { $0.count == 2 }
					.map { ($0[0], $0[1]) }
					.reduce(into: [String: String]()) { $0[$1.0] = $1.1 }
			}

			if line.contains("Build description path: ") {
				guard let startIndex = line.firstIndex(of: ":") else { continue }

				let stripped = line[line.index(after: startIndex)..<line.endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
				// Stripped will be to the build description path, we want the root of the build path which is 6 folders up
				buildCachePath = String(stripped).fileURL
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent()
			}

			// TODO: validate on guid??
			let retVal = target(from: line)
			if retVal.target != nil {
				currentTarget = retVal.target
				currentProject = retVal.project
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

			logger.debug(
				"""
				Found \(compilerCommand.compiler.rawValue) compiler command \
				for target: \(currentTarget.name) [\(currentTarget.guid)] \
				in project: \(currentProject!.name) [\(currentProject!.guid)]
				""")

			currentTarget.commands.append(compilerCommand)
		}
	}

	/// Is the index provided part of a compiler command block
	/// - Parameters:
	///   - lines: all the lines in the build log
	///   - index: the index of the line to search from
	/// - Returns: true if it's determined that the index is part of compiler command block
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

	/// Returns the target from the given line
	/// - Parameter line: the line to parse
	/// - Returns: the name of the target if one was found, otherwise nil
	private func target(from line: String) -> (target: GenTarget?, project: GenProject?) {
		if let startIndex = line.range(of: "(in target '")?.upperBound, let endIndex = line.range(of: "' from ")?.lowerBound {
			let targetName = String(line[startIndex..<endIndex])

			// get the project name
			guard let pStartIndex = line.range(of: "from project '")?.upperBound,
				let pEndIndex = line[endIndex...].range(of: "')")?.lowerBound else {
					logger.error("Unable to find project name from build target")
					return (nil, nil)
				}

			let projectName = String(line[pStartIndex..<pEndIndex])
			// logger.debug("Found target named \(targetName) in project named \(projectName)")

			// given the project name, find GenProject
			for prj in self.projects {
				// swiftlint:disable:next for_where
				if projectName == prj.name {
					// logger.debug("Matched with project \(p.name) [guid: \(p.guid)]")
					// walk the list of targets for this project, looking for a match
					if prj.targets == nil {
						return (nil, nil)
					}

					for tgt in prj.targets! {
						if targetName == tgt.name && tgt.hasSource == true {
							// logger.debug("Matched with target \(t.name) [guid: \(t.guid)]")
							return (tgt, prj)
						}
					}
				}
			}

			logger.error("Unable to match project '\(projectName)' and target '\(targetName)' with an existing project/target!!")
			return (nil, nil)
		}

		return (nil, nil)
	}

	/// Returns the compiler command from a line, if one exists
	/// - Parameter line: the line to parse
	/// - Returns: the compiler command if one was successfully parsed
	private func compilerCommand(from line: String) -> CompilerCommand? {
		var stripped = line
		if let index = stripped.firstIndexWithEscapes(of: "/"), index != stripped.startIndex {
			stripped = String(stripped[index..<stripped.endIndex])
		}

		// Ignore preprocessing of assembly files
		if stripped.contains("-x assembler-with-cpp") { return nil }

		// Note: the spaces here are so we don't match subpaths
		if stripped.contains("/swiftc ") {
			return .init(command: stripped, compiler: .swiftc)
		} else if stripped.contains("/clang ") {
			return .init(command: stripped, compiler: .clang)
		}

		return nil
	}
}
