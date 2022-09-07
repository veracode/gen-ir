//
//  CompilerCommandRunner.swift
//  
//
//  Created by Thomas Hedderwick on 29/08/2022.
//

import Foundation
import Logging

struct CompilerCommandRunner {
	/// List of compiler commands found in the build log
	private let commands: [CompilerCommand]

	/// The directory to place the LLVM IR output
	private let output: URL

	enum Error: Swift.Error {
		case failedToParse(String)
	}

	init(commands: [CompilerCommand], output: URL) {
		self.commands = commands
		self.output = output
	}

	/// Runs the compiler commands, modifying them to emit IR
	func run() throws {
		let tempDirectory = NSTemporaryDirectory().appending("gen-sil\(UUID().uuidString)").fileURL
		try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: tempDirectory) }

		logger.debug("Using temp directory as working directory: \(tempDirectory.filePath)")
		logger.info("Total commands to run: \(commands.count)")

		var moduleID = 0

		for (index, command) in commands.enumerated() {
			logger.info("Running command \(index) of \(commands.count), total modules processed: \(moduleID)")

			let fixedCommand = fixup(command: command.command)
			let (executable, arguments) = try split(command: fixedCommand)
			let fixedArguments = fixup(arguments: arguments, for: command.compiler)

			let result = try Process.runShell(executable, arguments: fixedArguments, runInDirectory: tempDirectory)

			logger.debug(
				"""
				Command ran: \(result.code) - has stdout: \(String(describing: result.stdout?.isEmpty)), \
				has stderr: \(String(describing: result.stderr?.isEmpty))
				"""
			)

			if command.compiler == .swiftc {
				try splitSwiftOutput(result, moduleID: &moduleID, to: output)
			} else if command.compiler == .clang {
				try moveClangOutput(from: tempDirectory, to: output)
			}
		}
	}

	/// Corrects the compiler command by removing options that aren't needed, slims down the output, or is otherwise required to be fixed before use
	/// - Parameter command: The command to fix
	/// - Returns: The fixed command
	private func fixup(command: String) -> String {
		command.unescaped()
			.replacingOccurrences(of: "\\=", with: "=")
		// this reduces the output by telling the driver to not output JSON, saves a _lot_ of memory
			.replacingOccurrences(of: "-parseable-output ", with: "")
		// for some reason this throws an error if included?
			.replacingOccurrences(of: "-use-frontend-save-temps", with: "")
	}

	/// Corrects the compiler arguments by removing options that aren't needed and adds options to emit IR
	/// - Parameters:
	///   - arguments: The arguments to correct
	///   - compiler: The compiler the arguments relate to
	/// - Returns: The fixed arguments
	private func fixup(arguments: [String], for compiler: Compiler) -> [String] {
		var arguments = arguments

		switch compiler {
		case .swiftc:
			arguments.append("-emit-ir")
		case .clang:
			arguments.append(contentsOf: ["-emit-llvm", "-S"])
			if let outputArgument = arguments.firstIndex(of: "-o") {
				// remove the output & filepath arguments, this will make the compiler emit the IR to the current working directory
				arguments.remove(at: arguments.index(after: outputArgument))
				arguments.remove(at: outputArgument)
			}
		}

		return arguments
	}

	/// Splits a command string into the executable and an array of arguments
	/// - Parameter command: The command to split
	/// - Returns: A tuple of the executable and an array of arguments
	private func split(command: String) throws -> (String, [String]) {
		// For the executable: substring up to the first whitespace
		guard let index = command.firstIndexWithEscapes(of: " ") else {
			throw Error.failedToParse("Failed to find executable for command: \(command)")
		}

		let executable = String(command[command.startIndex..<index])

		// For the arguments: split on whitespace from the executable index ignoring \\ escapes
		var arguments = [String]()
		var splitIndex: String.Index? = command.index(after: index)

		while splitIndex != nil, splitIndex! != command.endIndex {
			let nextIndex = command.firstIndexWithEscapes(of: " ", from: command.index(after: splitIndex!)) ?? command.endIndex

			arguments.append(String(command[splitIndex!..<nextIndex]).trimmingCharacters(in: .whitespacesAndNewlines))

			splitIndex = nextIndex
		}

		return (executable, arguments)
	}

	/// Splits the output (IR Modules) of the swift compiler and writes them to disk at the specified output location
	///
	/// Swiftc doesn't name outputs like Clang does, so we use the `moduleID` parameter to track how many modules we've already seen
	/// - Parameters:
	///   - result: The return value from the swiftc invocation
	///   - moduleID: The module ID that was last used
	///   - output: The destination path to write results to
	private func splitSwiftOutput(_ result: Process.ReturnValue, moduleID: inout Int, to output: URL) throws {
		if let error = result.stderr, !error.isEmpty {
			// This will have a _bunch_ of cruft, and then the modules...
			// So we have to: remove the cruft, split the modules
			let modules = try splitModules(error)

			for module in modules {
				let modulePath = output.appendingPathComponent("\(moduleID).ll")
				do {
					try module.write(to: modulePath, atomically: true, encoding: .utf8)
				} catch {
					logger.error("Failed to write module \(moduleID) to path: \(modulePath) with error: \(error)")
				}

				moduleID += 1
			}
		}
	}

	/// Splits a string of LLVM IR modules into an array of LLVM IR modules
	///
	/// Again, this is because swiftc outputs all modules as one big blob of text
	/// - Parameters:
	///   - text: The string to split
	/// - Returns: An array of module contents, with each entry representing a module
	private func splitModules(_ text: String) throws -> [String] {
		let moduleMarker = "; ModuleID ="

		// find all indicies of the module markers (for splitting on)
		let indicies = text.indicies(of: moduleMarker)

		var modules = [String]()

		for index in 0..<indicies.count {
			let startIndex = indicies[index]
			let endIndex = index < (indicies.count - 1) ? indicies[index + 1] : text.endIndex

			modules.append(String(text[startIndex..<endIndex]))
		}

		return modules
	}

	/// Moves the output artifacts of clang from a specified source to a specified destination
	///
	/// Clang will output LLVM IR into files in the current working directory, so we need to move them to the user specified location
	/// - Parameters:
	///   - source: The directory to search for IR files in
	///   - destination: The destination directory to place the files in
	private func moveClangOutput(from source: URL, to destination: URL) throws {
		let files = try FileManager.default.getFiles(at: source, withSuffix: ".ll")

		for file in files {
			let destinationPath = destination.appendingPathComponent(file.lastPathComponent)

			if FileManager.default.fileExists(atPath: destinationPath.filePath) {
				try FileManager.default.removeItem(at: destinationPath)
			}

			try FileManager.default.moveItem(at: file, to: destination.appendingPathComponent(file.lastPathComponent))
		}
	}
}
