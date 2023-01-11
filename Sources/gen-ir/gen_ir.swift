import Foundation
import ArgumentParser
import Logging

/// Global logger object
var logger: Logger!

let programName = CommandLine.arguments.first!

/// Command to emit LLVM IR from an Xcode build log
@main
struct IREmitterCommand: ParsableCommand {

	static let configuration = CommandConfiguration(
		commandName: "",
		abstract: "Consumes an Xcode build log, and outputs LLVM IR, in the bitstream format, to the folder specified",
		discussion:
		"""
		This can either be done via a file, or via stdin. You may have to redirect stderr to stdin before piping it to this tool.

		This tool requires a full Xcode build log in order to capture all files in the project. If this is not provided, \
		you may notice that not all modules are emitted.

		To ensure this, run `xcodebuild clean` first before you `xcodebuild build` command.

		Example with build log:
			$ xcodebuild clean && xcodebuild build -project MyProject.xcodeproj -configuration Debug -scheme MyScheme > log.txt
			$ \(programName) log.txt output_folder/

		Example with pipe:
			$ xcodebuild clean && xcodebuild build -project MyProject.xcodeproj -configuration Debug -scheme MyScheme 2>&1 | \(programName) - output_folder/
		""",
		version: "v\(Versions.version)"
	)

	/// Path to an Xcode build log, or `-` if build log should be read from stdin
	@Argument(help: "Path to a full Xcode build log. If `-` is provided, stdin will be read")
	var logPath: String

	/// Path to write the LLVM BC results to
	@Argument(help: "Directory to write output to")
	var outputPath: String

	/// Enables enhanced debug logging
	@Flag(help: "Enables debug level logging")
	var debug = false

	@Flag(help: "Reduces log noise by suppressing xcodebuild output when reading from stdin")
	var quieter = false

	func run() throws {
		LoggingSystem.bootstrap(StdOutLogHandler.init)
		logger = Logger(label: Bundle.main.bundleIdentifier ?? "com.veracode.gen-ir")

		if debug {
			logger.logLevel = .debug
		}

		let parser = try parser(for: logPath)
		let output = outputPath.fileURL

		if !FileManager.default.directoryExists(at: output) {
			logger.debug("Output path doesn't exist, creating \(output)")
			try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
		}

		let runner = CompilerCommandRunner(
			targetToCommands: parser.targetToCommands,
			targetToProduct: parser.targetToProduct,
			output: output
		)

		try runner.run()
	}

	/// Gets an `XcodeLogParser` for a path
	/// - Parameter path: The path to a file on disk containing an Xcode build log, or `-` if stdin should be read
	/// - Returns: An `XcodeLogParser` for the given path
	private func parser(for path: String) throws -> XcodeLogParser {
		if path == "-" {
			logger.info("Collating input via pipe")
			let parser =  try XcodeLogParser(log: readStdin())
			logger.info("Finished reading from pipe")
			return parser
		} 

		logger.info("Reading from log file")
		return try XcodeLogParser(path: path.fileURL)
	}

	/// Reads stdin until an EOF is found
	/// - Returns: An array of Strings representing stdin split by lines
	private func readStdin() -> [String] {
		var results = [String]()

		while let line = readLine() {
			if !quieter {
				print(line) // shows user that build is happening
			}
			results.append(line)
		}

		if !quieter {
			print("\n\n")
		}

		return results
	}
}
