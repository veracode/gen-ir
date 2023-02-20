//
//  CompilerCommandRunner.swift
//  
//
//  Created by Thomas Hedderwick on 29/08/2022.
//

import Foundation
import Logging
import PBXProjParser

/// A model of the contents of an output file map json
typealias OutputFileMap = [String: [String: String]]

/// A runner responsible for editing and running compiler commands, and moving or splitting the output to a given location.
///
/// >  swiftc will emit LLVM BC files to the build directory. In this case, the runner will look for the OutputFileMap to locate the path of the BC files, and move them to the output location
///
/// > clang will emit LLVM BC to the current working directory in a named file. In this case, the runner will  move the files from temporary storage to the output location
struct CompilerCommandRunner {
	/// Map of targets and the compiler commands that were part of the target build
	private let targetToCommands: TargetToCommands
	/// Map of target to product names
	private let targetToProduct: TargetToProduct

	/// The directory to place the LLVM BC output
	private let output: URL

	private let fileManager = FileManager.default

	enum Error: Swift.Error {
		/// Command runner failed to parse the command for the required information
		case failedToParse(String)
	}

	/// Initializes a runner
	/// - Parameters:
	///   - targetToCommands: Mapping of targets to the commands used to generate them
	///   - targetToProduct: Mapping of target names to product names
	///   - output: The location to place the resulting LLVM IR
	init(
		targetToCommands: TargetToCommands,
		targetToProduct: TargetToProduct,
		output: URL
	) {
		self.targetToCommands = targetToCommands
		self.targetToProduct = targetToProduct
		self.output = output
	}

	/// Starts the runner
	func run() throws {
		let tempDirectory = try fileManager.temporaryDirectory(named: "gen-ir\(UUID().uuidString)")
		defer { try? fileManager.removeItem(at: tempDirectory) }
		logger.debug("Using temp directory as working directory: \(tempDirectory.filePath)")

		let totalCommands = targetToCommands.reduce(0, { $0 + $1.value.count })
		logger.info("Total commands to run: \(totalCommands)")

		var totalModulesRun = 0

		for (target, commands) in targetToCommands {
			logger.info("Operating on target: \(target). Total modules processed: \(totalModulesRun)")

			totalModulesRun += try run(commands: commands, for: target, at: tempDirectory)
		}

		let uniqueModules = try fileManager.files(at: output, withSuffix: ".bc").count
		logger.info("Finished compiling all targets. Unique modules: \(uniqueModules)")

		try fileManager.moveItemReplacingExisting(from: tempDirectory, to: output)
	}

	/// Runs all commands for a given target
	/// - Parameters:
	///   - commands: The commands to run
	///   - target: The target these commands relate to
	///   - directory: The directory to run these commands in
	/// - Returns: The total amount of modules produced for this target
	private func run(commands: [CompilerCommand], for target: String, at directory: URL) throws -> Int {
		let directoryName = targetToProduct[target] ?? target
		let targetDirectory = directory.appendingPathComponent(directoryName)

		try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
		logger.debug("Created target directory: \(targetDirectory)")

		var targetModulesRun = 0

		for (index, command) in commands.enumerated() {
			logger.info(
				"""
				Running command (\(command.compiler.rawValue)) \(index + 1) of \(commands.count). \
				Target modules processed: \(targetModulesRun)
				"""
			)

			let (executable, arguments) = try parse(command: command)
			let result = try Process.runShell(executable, arguments: arguments, runInDirectory: directory)

			if result.code != 0 {
				logger.debug(
				"""
				Command finished:
					- code: \(result.code)
					- has stdout: \(String(describing: result.stdout?.isEmpty))
					- has stderr: \(String(describing: result.stderr?.isEmpty))
				"""
				)
			}

			var clangAdditionalModules = 0
			var swiftAdditionalModules = 0

			switch command.compiler {
			case .swiftc:
				guard let outputFileMap = try getOutputFileMap(from: arguments) else {
					logger.error("Failed to find OutputFileMap for command \(command.command) ")
					break
				}

				swiftAdditionalModules = try moveSwiftOutput(from: outputFileMap, to: targetDirectory)
			case .clang:
				clangAdditionalModules = try moveClangOutput(from: directory, to: targetDirectory)
			}

			if clangAdditionalModules == 0 && swiftAdditionalModules == 0 {
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
			// Clang, if given -fembed-bitcode & -emit-bc will emit.... Textual ASM????
			// swiftc behaves correctly and ignores the embed flag
			.replacingOccurrences(of: "-fembed-bitcode", with: "")
	}

	/// Corrects the compiler arguments by removing options block BC generation and adding options to emit BC
	/// - Parameters:
	///   - arguments: The arguments to correct
	///   - compiler: The compiler the arguments relate to
	/// - Returns: The fixed arguments
	private func fixup(arguments: [String], for compiler: Compiler) -> [String] {
		var arguments = arguments

		switch compiler {
		case .swiftc:
			// When using this option, swiftc will output the .bc file to DerivedData/Build folder
			// FIXME: if SR-327 ever happens, we should update
			arguments.append("-emit-bc")
		case .clang:
			arguments.append(contentsOf: ["-S", "-Xclang", "-emit-llvm-bc"])
			if let outputArgument = arguments.firstIndex(of: "-o") {
				// remove the output location, forces emitting to the current working directory
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
}

// MARK: - Swiftc specific functions
extension CompilerCommandRunner {
	/// Moves all BC files detected in the output map to the target directory
	/// - Parameters:
	///   - outputMap: The output file map to parse for bc file paths
	///   - targetDirectory: The target directory to place the BC files
	/// - Returns: The total amount of bitcode paths moved
	private func moveSwiftOutput(from outputMap: OutputFileMap, to targetDirectory: URL) throws -> Int {
		// read the contents of the output file map, and extract the bitcode path for each file
		let bitcodePaths = bitcodeFiles(from: outputMap)

		for bitcodePath in bitcodePaths {
			let destination = targetDirectory.appendingPathComponent(bitcodePath.lastPathComponent)
			try fileManager.moveItemReplacingExisting(from: bitcodePath, to: destination)
		}

		return bitcodePaths.count
	}

	/// Gets BC paths for an output file map
	/// - Parameter outputMap: The output file map to parse
	/// - Returns: An array of BC file path URLs found in the output map
	private func bitcodeFiles(from outputMap: OutputFileMap) -> [URL] {
		outputMap.compactMap { (source, values) in
			// First key in the OutputFileMap is always empty, ignore it
			guard !source.isEmpty else { return nil }

			return values["llvm-bc"]?.fileURL
		}
	}

	/// Finds, and parses an output file map from an array of compiler flags
	/// - Parameter arguments: The arguments to parse
	/// - Returns: An `OutputFileMap` representing the output file map
	private func getOutputFileMap(from arguments: [String]) throws -> OutputFileMap? {
		guard let index = arguments.firstIndex(of: "-output-file-map") else {
			return nil
		}

		let path = arguments[index + 1].fileURL

		guard fileManager.fileExists(atPath: path.filePath) else {
			logger.error("Found an OutputFileMap, but it doesn't exist on disk? Please report this issue.")
			logger.debug("OutputFileMap path: \(path)")
			return nil
		}

		let data = try Data(contentsOf: path)
		return try JSONDecoder().decode(OutputFileMap.self, from: data)
	}
}

// MARK: - Clang specific functions
extension CompilerCommandRunner {
	/// Moves the output artifacts of clang from a specified source to a specified destination
	///
	/// Clang will output LLVM IR into files in the current working directory, so we need to move them to the user specified location
	/// - Parameters:
	///   - source: The directory to search for IR files in
	///   - destination: The destination directory to place the files in
	/// - Returns: The total number of files moved
	private func moveClangOutput(from source: URL, to destination: URL) throws -> Int {
		let files = try fileManager.files(at: source, withSuffix: ".s")

		for file in files {
			let destinationPath = destination.appendingPathComponent(
				file.lastPathComponent.replacingOccurrences(of: ".s", with: ".bc")
			)

			try fileManager.moveItemReplacingExisting(from: file, to: destinationPath)
		}

		return files.count
	}
}
