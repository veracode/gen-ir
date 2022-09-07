//
//  CompilerCommandRunner.swift
//  
//
//  Created by Thomas Hedderwick on 29/08/2022.
//

import Foundation
import Logging

/// A runner responsible for editing and running compiler commands, and moving or splitting the output to a given location.
///
/// >  swiftc will emit LLVM IR to stderr (???) and will output multiple modules at once, this means the runner has to parse the output looking for module markers and
/// > attempt to split the modules into separate files. These need to be numbered as swiftc doesn't set module/file names for the output.
///
/// > clang will emit LLVM IR to the current working directory in a named file.
/// > The runner in this case is responsible for managing the temporary storage, and moving of the files.
struct CompilerCommandRunner {
	/// Map of targets and the compiler commands that were part of the target build
	private let targetsAndCommands: TargetsAndCommands

	/// The directory to place the LLVM IR output
	private let output: URL

	private let fileManager = FileManager.default

	enum Error: Swift.Error {
		/// Command runner failed to parse the command for the required information
		case failedToParse(String)
	}

	/// Initializes a runner
	/// - Parameters:
	///   - targetsAndCommands: Mapping of targets to the commands used to generate them
	///   - output: The location to place the resulting LLVM IR
	init(targetsAndCommands: TargetsAndCommands, output: URL) {
		self.targetsAndCommands = targetsAndCommands
		self.output = output
	}

	/// Starts the runner
	func run() throws {
		let tempDirectory = try fileManager.temporaryDirectory(named: "gen-sil\(UUID().uuidString)")
		defer { try? fileManager.removeItem(at: tempDirectory) }
		logger.debug("Using temp directory as working directory: \(tempDirectory.filePath)")

		let totalCommands = targetsAndCommands.reduce(0, { $0 + $1.value.count })
		logger.info("Total commands to run: \(totalCommands)")

		var totalModulesRun = 0

		for (target, commands) in targetsAndCommands {
			logger.info("Operating on target: \(target). Total modules processed: \(totalModulesRun)")

			totalModulesRun += try run(commands: commands, for: target, at: tempDirectory)
		}
	}

	/// Runs all commands for a given target
	/// - Parameters:
	///   - commands: The commands to run
	///   - target: The target these commands relate to
	///   - directory: The directory to run these commands in
	/// - Returns: The total amount of modules produced for this target
	private func run(commands: [CompilerCommand], for target: String, at directory: URL) throws -> Int {
		let targetDirectory = output.appendingPathComponent(target)
		try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
		logger.debug("Created target directory: \(targetDirectory)")

		var targetModulesRun = 0
		var swiftModuleID = 0

		for (index, command) in commands.enumerated() {
			logger.info("Running command \(index + 1) of \(commands.count). Target modules processed: \(targetModulesRun)")

			let (executable, arguments) = try parse(command: command)
			let result = try Process.runShell(executable, arguments: arguments, runInDirectory: directory)

			logger.debug(
				"""
				Command finished:
					- code: \(result.code)
					- has stdout: \(String(describing: result.stdout?.isEmpty))
					- has stderr: \(String(describing: result.stderr?.isEmpty))
				"""
			)

			var clangAdditionalModules = 0
			var swiftAdditionalModules = 0

			switch command.compiler {
			case .swiftc:
				guard let stderr = result.stderr else {
					logger.error("stderr was empty for swiftc run, possible failure?")
					continue
				}

				let modules = try splitModules(stderr)
				swiftAdditionalModules = modules.count

				try modules.forEach { module in
					let modulePath = targetDirectory.appendingPathComponent("\(swiftModuleID).ll")
					try module.write(to: modulePath, atomically: true, encoding: .utf8)

					swiftModuleID += 1
				}
			case .clang:
				clangAdditionalModules = try moveClangOutput(from: directory, to: targetDirectory)
			}

			if clangAdditionalModules == 0 && swiftModuleID == 0 {
				logger.error(
					"""
					No modules were produced from compiler, potential failure. Results: \n\n \
					executable: \(executable)\n\n \
					arguments: \(arguments.joined(separator: " "))\n\n \
					stdout: \(result.stdout ?? "None")\n\n \
					stderr: \(result.stderr ?? "None")
					"""
				)
			} else {
				targetModulesRun += (clangAdditionalModules + swiftAdditionalModules)
			}
		}

		return targetModulesRun
	}

	/// Parses, and corrects, the executable name and arguments for a given command.
	/// - Parameter command: The command to parse and correct
	/// - Returns: A tuple of executable name and an array of arguments
	private func parse(command: CompilerCommand) throws -> (String, [String]) {
		let fixed = fixup(command: command.command)
		let (executable, arguments) = try split(command: fixed)
		let fixedArguments = fixup(arguments: arguments, for: command.compiler)

		return (executable, fixedArguments)
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
			throw Error.failedToParse("Failed to parse executable for command: \(command)")
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

		// find all indices of the module markers (for splitting on)
		let indices = text.indices(of: moduleMarker)

		var modules = [String]()

		for index in 0..<indices.count {
			let startIndex = indices[index]
			let endIndex = index < (indices.count - 1) ? indices[index + 1] : text.endIndex

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
	/// - Returns: The total number of files moved
	private func moveClangOutput(from source: URL, to destination: URL) throws -> Int {
		let files = try fileManager.files(at: source, withSuffix: ".ll")

		for file in files {
			let destinationPath = destination.appendingPathComponent(file.lastPathComponent)

			if fileManager.fileExists(atPath: destinationPath.filePath) {
				try fileManager.removeItem(at: destinationPath)
			}

			try fileManager.moveItem(at: file, to: destination.appendingPathComponent(file.lastPathComponent))
		}

		return files.count
	}
}
