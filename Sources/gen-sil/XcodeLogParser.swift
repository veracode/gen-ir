//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 22/08/2022.
//

import Foundation

/// Represents the source files, by type, in a project
struct Sources {
	/// Paths of the Swift files in this project
	let swiftFiles: Set<URL>

	/// Paths of the Objective-C files in this project
	let objcFiles: Set<URL>
}

// TODO: use new regex where possible
public struct XcodeLogParser {
	private var commands: [String] = []
	private let log: [String]

	enum Error: Swift.Error {
		case encoding
		case noTarget(String)
	}

	init(path: URL) throws {
		self.log = try String(contentsOf: path).components(separatedBy: .newlines)
		self.commands = log.filter {
			$0.contains("/swiftc") || $0.contains("/clang")
		}
	}

	func parse() throws {
		var moduleID = 0

		for command in commands {
			print("Running command \(commands.firstIndex(of: command)!) - on module: \(moduleID)")
			let unescaped = command.unescaped()
				.appending(" -emit-ir")
				.replacingOccurrences(of: "\\", with: "")
				.replacingOccurrences(of: "-parseable-output ", with: "") // this reduces the output by telling the driver to not output JSON

			// TODO: Change this to a split on the first index of whitespace to save some cycles
			let split = unescaped.split(separator: " ").map { String($0) }

			let result = try Process.runShell(split.first!, arguments: Array(split.dropFirst()))

			print("Command ran: \(result.code) - out: \(String(describing: result.stdout?.isEmpty)), err: \(String(describing: result.stderr?.isEmpty))")

			if let output = result.stdout, !output.isEmpty {
				print("output: \(output)")
			}

			if let error = result.stderr, !error.isEmpty {
				// This will have a _bunch_ of cruft, and then the modules...
				// So we have to: remove the cruft, split the modules
				var previous = moduleID
				try splitModules(error, index: &moduleID)
				if moduleID == previous {
					print("error: \(error)")
				}
			}
		}
	}

	private func splitModules(_ text: String, index: inout Int) throws {
		let moduleMarker = "; ModuleID ="

//		find all indicies of the module markers (for splitting on)
		let indicies = text.indicies(of: moduleMarker)

		var modules = [String]()

		for i in 0..<indicies.count {
			let index = indicies[i]
			let nextIndex = i < (indicies.count - 1) ? indicies[i + 1] : text.endIndex

			modules.append(String(text[index..<nextIndex]))
		}

		// TODO: better error handling - don't want to fail if one module is wrong
		try modules.forEach {
			try $0.write(toFile: "/Users/thedderwick/Desktop/gen_sil_test/\(index).ll", atomically: true, encoding: .utf8)
			index += 1
		}
	}

//	private func getTarget() throws -> String {
//		// TODO: use new regex engine here if possible
//		for line in commands {
//			let regex = try NSRegularExpression(pattern: "[\\s]+-target[\\s]+([^\\s]*).*")
//
//			if let match = regex.matches(in: line, range: NSRange(location: 0, length: line.count)).first {
//				return (line as NSString).substring(with: match.range(at: 1))
//			}
//		}
//
//		throw Error.noTarget("Failed to find a target in build log")
//	}
//
//	private func getSourceFiles() throws -> Sources {
//		// TODO: check if we can simplify these
//		let swiftFileRegex = try NSRegularExpression(pattern: "(/([^ ]|(?<=\\\\) )*\\.swift(?<!\\\\)) ")
//		let objcFileRegex = try NSRegularExpression(pattern: "(/([^ ]|(?<=\\\\) )*\\.m(?<!\\\\)) ")
//
//		var swiftFiles = Set<URL>()
//		var objcFiles = Set<URL>()
//
//		func extractFileURLs(_ regex: NSRegularExpression, from text: String) -> [URL] {
//			regex.matches(in: text, range: .init(location: 0, length: text.count))
//				.map {
//					(text as NSString).substring(with: $0.range(at: 1)).unescaped().fileURL
//				}
//		}
//
//		for line in log {
////			let swiftMatches = swiftFileRegex.matches(in: line, range: NSRange(location: 0, length: line.count))
////			let swiftResults = swiftMatches.map {
////				(line as NSString).substring(with: $0.range(at: 1)).unescaped().fileURL
////			}
//
//			extractFileURLs(swiftFileRegex, from: line).forEach { swiftFiles.insert($0) }
//
////			let objcMatches = objcFileRegex.matches(in: line, range: NSRange(location: 0, length: line.count))
////			let objcResults = objcMatches.map {
////				(line as NSString).substring(with: $0.range(at: 1)).unescaped().fileURL
////			}
//
//			extractFileURLs(objcFileRegex, from: line).forEach { swiftFiles.insert($0) }
//		}
//
//		return .init(swiftFiles: swiftFiles, objcFiles: objcFiles)
//	}
}
