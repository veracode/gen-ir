import Foundation
import ArgumentParser

// This project is heavily inspired by: https://blog.digitalrickshaw.com/2016/03/14/dumping-the-swift-ast-for-an-ios-project-part-2.html

let toolName = ((CommandLine.arguments.first! as NSString).lastPathComponent as String)

@main
struct ArtifactBuilder: ParsableCommand {
	enum Configuration: String, CaseIterable {
		case xcode
		case cli
	}

	static let configuration = CommandConfiguration(
		commandName: "",
		subcommands: [XcodeArtifactBuilder.self, CLIArtifactBuilder.self]
	)


}

extension ArtifactBuilder {
	struct XcodeArtifactBuilder: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "xcode",
			abstract: "Runs \(toolName) in Xcode mode",
			discussion:
			"""
			When running this tool in Xcode mode (normally when used as part of a Run Script Phase, the required input is
			derived from the environment. This requires that certain environment variables are set by Xcode.
			"""
		)

		@Argument(help: "Output directory to write to")
		var outputPath: String?

		func run() throws {
			// TODO: present user-sensible errors here
			var environment = ProcessInfo.processInfo.environment

			if let outputPath {
				environment[XcodeConfigurationKeys.outputPath.rawValue] = outputPath
			}
			
			let config = try XcodeConfiguration(from: environment)
			let runner = try XcodeRunner(configuration: config)
			try runner.run()
		}
	}
}

extension ArtifactBuilder {
	struct CLIArtifactBuilder: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "cli",
			abstract: "Runs \(toolName) in CLI mode",
			discussion: "When running this tool in CLI mode required input is taken via the command line."
		)

		@Option(name: .shortAndLong, help: "", transform: PathOption.init)
		var path: PathOption

		@Option(name: .shortAndLong, help: "Output directory to write to")
		var output: String

		enum PathOption {
			case path(PathType)

			init(_ string: String) throws {
				if string.hasSuffix("xcodeproj") {
					self = .path(.project(string.fileURL))
				} else if string.hasSuffix("xcworkspace") {
					self = .path(.workspace(string.fileURL))
				} else {
					throw ValidationError("Path is required to end in either 'xcodeproj' or 'xcworkspace'.")
				}

				// We do this check as this user provided input will eventually make it to various shell commands
				var isDirectory = ObjCBool(false)
				guard FileManager.default.fileExists(atPath: string, isDirectory: &isDirectory) else {
					throw ValidationError("Path should be an existing folder")
				}

				if isDirectory.boolValue {
					throw ValidationError("Path should be an xcodeproj or xcworkspace folder, not a file")
				}
			}
		}

		func run() throws {
			guard case .path(let pathType) = path else {
				throw ValidationError("Path is a required argument")
			}

			let runner = try CLIRunner(configuration: CLIConfiguration(pathType, output: output.fileURL))
			try runner.run()
		}
	}
}
