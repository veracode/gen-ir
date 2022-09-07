import Foundation
import ArgumentParser

// This project is heavily inspired by: https://blog.digitalrickshaw.com/2016/03/14/dumping-the-swift-ast-for-an-ios-project-part-2.html

let toolName = ((CommandLine.arguments.first! as NSString).lastPathComponent as String)

/// This structure encapsulates the various modes of operation of the program via subcommands
@main
struct ArtifactBuilder: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "",
		discussion:
			// TODO: rewrite this
		"""
		It is important to note, this tool requires access to build artifacts - this means it is required that a **debug** iOS build has been performed with the current version of the project.
		""",
		subcommands: [XcodeArtifactBuilder.self, CLIArtifactBuilder.self, StdInArtifactBuilder.self, LogArtifactBuilder.self]
	)
}

extension ArtifactBuilder {
	struct StdInArtifactBuilder: ParsableCommand {
		enum Error: Swift.Error {
			case failedToReadStdin(String)
		}

		static let configuration = CommandConfiguration(
			commandName: "-",
			abstract: "Consumes a build log via stdin or log file",
			discussion:
				"""
				When running this command, a build log is expected via stdin. This can be accomplished by piping the
				result of an xcodebuild command into the tool or pointing it to a build log.

				Note: a _full_ build is required in order to capture the compiler commands for each file in the project.
				To ensure this, run `xcodebuild clean` first.

				Example:
					$ xcodebuild clean && xcodebuild build | gen_sil build-log -
				"""
		)

		@Argument(help: "Output directory to write to")
		var outputPath: String

		func run() throws {
			print("running -")

			guard let input = readStdin() else {
				throw Error.failedToReadStdin("Failed to read the build log via stdin")
			}
		}

		private func readStdin() -> String? {
			var result: String?

			while let line = readLine() {
				if var result {
					result.append("\n\(line)")
				} else {
					result = line
				}
			}

			return result
		}
	}
}

extension ArtifactBuilder {
	struct LogArtifactBuilder: ParsableCommand {
		enum Error: Swift.Error {
			case pathDoesntExists(URL)
			case encodingError(String)
		}

		static let configuration = CommandConfiguration(
			commandName: "log",
			abstract: "Consumes a build log file",
			discussion:
			"""
			When running this command, a clean build log is expected at the path provided.

			Note: a _full_ build is required in order to capture the compiler commands for each file in the project.
			To ensure this, run `xcodebuild clean` first.

			Example:
				$ xcodebuild clean && xcodebuild build > log.txt
				$ gen-sil log --output output -
			"""
		)

		@Argument(help: "A full Xcode build log")
		var logPath: String

		@Argument(help: "Output directory to write to")
		var outputPath: String

		func run() throws {
			print("running log: \(CommandLine.arguments)")

			let path = logPath.fileURL

			guard FileManager.default.fileExists(atPath: logPath) else {
				throw Error.pathDoesntExists(path)
			}

			let parser = try XcodeLogParser(path: path)
			try parser.parse()
		}
	}
}

extension ArtifactBuilder {
	/// The Xcode submcommand
	///
	/// This subcommand is intended to be run from an Xcode Run Script Build Phase, this inherits most of it's configuration from the environment.
	struct XcodeArtifactBuilder: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "xcode",
			abstract: "Runs \(toolName) in Xcode mode",
			discussion:
			"""
			When running this tool in Xcode mode (normally when used as part of a Run Script Phase) the required input is
			derived from the environment. This requires that certain environment variables are set by Xcode.
			"""
		)

		@Option(name: .shortAndLong, help: "The Scheme to use")
		var scheme: String

		@Argument(help: "Output directory to write to")
		var outputPath: String

		func run() throws {
			// TODO: present user-sensible errors here
			var environment = ProcessInfo.processInfo.environment

			environment[XcodeBuildSettingsKeys.outputPath.rawValue] = outputPath
			environment["SCHEME"] = scheme
			
			let config = try XcodeConfiguration(from: environment)
			let runner = try XcodeRunner(configuration: config)
			try runner.run()
		}
	}
}

extension ArtifactBuilder {
	/// Represents a path to an Xcode project or workspace
	enum XcodeProjectPathOption {
		case path(XcodeProjectPath)

		init(_ string: String) throws {
			if string.hasSuffix("xcodeproj") {
				self = .path(.project(string.fileURL))
			} else if string.hasSuffix("xcworkspace") {
				self = .path(.workspace(string.fileURL))
			} else {
				throw ValidationError("Path is required to end in either 'xcodeproj' or 'xcworkspace'.")
			}

			// We do this check as this user provided input will eventually make it to various shell commands
			guard FileManager.default.directoryExists(at: string.fileURL) else {
				throw ValidationError("Path should be an existing xcodeproj or xcworkspace folder")
			}
		}
	}

	/// The CLI subcommand
	///
	/// This command is intended to be run from the command line. It gets it's configuration via the listed options.
	///
	/// Additional configuration is set by parsing of the input (i.e. xcodeproj)
	struct CLIArtifactBuilder: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "cli",
			abstract: "Runs \(toolName) in CLI mode",
			discussion: "When running this tool in CLI mode required input is taken via the command line."
		)

		@Option(name: .shortAndLong, help: "", transform: XcodeProjectPathOption.init)
		var path: XcodeProjectPathOption

		@Option(name: .shortAndLong, help: "Output directory to write to")
		var output: String

		@Option(name: .shortAndLong, help: "The Scheme to use")
		var scheme: String

		func run() throws {
			guard case .path(let pathType) = path else {
				throw ValidationError("Path is a required argument")
			}

			let runner = try CLIRunner(input: pathType, output: output.fileURL, scheme: scheme)
			try runner.run()
		}
	}
}
