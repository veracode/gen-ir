import Foundation
import ArgumentParser
import Logging

// This project is heavily inspired by: https://blog.digitalrickshaw.com/2016/03/14/dumping-the-swift-ast-for-an-ios-project-part-2.html

// TODO: List of TODOs:
// - Security Review, especially around executing commands - should we clense? How do we verify these?
// - How do we want to distribute? Homebrew? Downloads (NO)? Source? GitHub?
// - Do we want autoupdates?
// - DOCUMENT
// - TEST!!!!!!!
// - find a nice way to get a module & source file name for swiftc invocations

/// This structure encapsulates the various modes of operation of the program via subcommands
@main
struct ArtifactBuilder: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "",
		discussion:
			"""
			Note: This tool requires a **full** build log, this often means performing a clean before building.
			If you notice missing modules, please ensure you have done a clean build.
			""",
		subcommands: [LogArtifactBuilder.self]
	)
}

extension ArtifactBuilder {
	struct LogArtifactBuilder: ParsableCommand {

		enum Error: Swift.Error {
			case pathDoesntExists(URL)
			case failedToRead(String)
		}

		static let configuration = CommandConfiguration(
			commandName: "log",
			abstract: "Consumes an Xcode build log, and outputs LLVM IR to the folder specified",
			discussion:
			"""
			This can either be done via a file, or via stdin. You will have to redirect stderr to stdin before piping it to this tool.

			This tool requires a full Xcode build log in order to capture all files in the project. If this is not provided, \
			you may notice that not all modules are emitted.

			To ensure this, run `xcodebuild clean` first before you `xcodebuild build` command.

			Example with build log:
				$ xcodebuild clean && xcodebuild build -project MyProject.xcodeproj -configuration Debug -scheme MyScheme > log.txt
				$ gen-sil log output_folder/ log.txt

			Example with pipe:
				$ xcodebuild clean && xcodebuild build -project MyProject.xcodeproj -configuration Debug -scheme MyScheme 2>&1 | gen-sil log output_folder/ -
			"""
		)

		@Argument(help: "Directory to write LLVM IR files to")
		var outputPath: String

		@Argument(help: "Path to a full Xcode build log")
		var logPath: String?

		func run() throws {
			LoggingSystem.bootstrap(StdOutLogHandler.standard)

			let parser: XcodeLogParser
			let output = outputPath.fileURL
			var logger = Logger(label: Bundle.main.bundleIdentifier ?? "com.veracode.gen-ir")
			logger.logLevel = .debug

			if let last = CommandLine.arguments.last, last == "-" {
				logger.info("> Collating input via pipe")
				let input = readStdin()
				parser = try XcodeLogParser(log: input, logger: logger)
			} else if let logPath {
				logger.info("> Reading from log file")
				parser = try XcodeLogParser(path: logPath.fileURL, logger: logger)
			} else {
				throw Error.failedToRead("Failed to read build log via stdin or log file")
			}

			if !FileManager.default.directoryExists(at: output) {
				try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
			}

			let runner = CompilerCommandRunner(commands: parser.commands, output: output, logger: logger)

			try runner.run()
		}

		private func readStdin() -> [String] {
			var results = [String]()

			while let line = readLine() {
				results.append(line)
			}

			return results
		}
	}
}
