import Foundation

// Heavily inspired by https://blog.digitalrickshaw.com/2016/03/14/dumping-the-swift-ast-for-an-ios-project-part-2.html
@main
public struct gen_sil {
	private static let xcrun = "/usr/bin/xcrun"

	public static func main() throws {
		var environment = ProcessInfo.processInfo.environment
		let config: Configuration

		do {
			config = try Configuration(from: environment)
		} catch Configuration.Error.configurationError(let error) {
			print("Configuration error: \(error)")
			exit(1)
		} catch {
			print("Unexpected error: \(error)")
			exit(1)
		}

		// HACK: Because the new Xcode build system doesn't _yet_ support -dry-run
		// we essentially have to compile twice. Have a env flag to stop the second run
		// TODO: this will need to change - is there some metadata (or xcodeproj) we can parse for the file list?
		guard !config.shouldSkipGenSil else {
			print("============ should skip is set - skipping run ==============")
			exit(0)
		}

		// we now want to skip any new invocations of this tool
		environment["SHOULD_SKIP_GEN_SIL"] = "1"
    print("running xcodebuild from gen_sil")

		guard let archiveOutput = try runXcodeArchive(with: config, environment: environment) else {
			print("Failed to get output from xcodebuild archive command")
			exit(1)
		}

		guard let target = try parseTarget(from: archiveOutput) else {
			print("Failed to find target from output: ")
			archiveOutput.split(separator: "\n").forEach { print($0) }
			exit(1)
		}

		print("Found target: \(target)")

		guard let sourceFiles = try parseSourceFiles(from: archiveOutput) else {
			print("Failed to find source files from output: ")
			archiveOutput.split(separator: "\n").forEach { print($0) }
			exit(1)
		}

    print("------- source files ----------")
    print(sourceFiles)

		// emit IR for each source file
		try sourceFiles.map { file in
			getArguments(for: file, target: target, with: config)
		}.forEach { arguments in
			do {
				let result = try emitIR(with: arguments)
				print("result: \(result)")
			} catch {
				print("Failed to emit IR")
			}
		}

		exit(0)
	}

	private static func runXcodeArchive(with config: Configuration, environment: Environment) throws -> String? {
		// clean the project so Xcode doesn't skip invocations of swiftc
		_ = try Process.runShell(
			xcrun,
			arguments: [
				"xcodebuild", "clean"
			],
			environment: environment
		)

		// build the project
		return try Process.runShell(
			xcrun,
			arguments: [
				"xcodebuild",
				"archive",
				"-project", "\(config.projectName).xcodeproj",
				"-target", config.targetName,
				"-configuration", config.configuration,
				"-sdk", config.sdkName,
			],
			environment: environment
		)
	}

	/// Attempts to match a regex pattern in a string
	/// - Parameters:
	///   - regex: the regex pattern
	///   - text: the text to attempt to match against
	/// - Returns: the matches
	private static func match(regex: String, in text: String) throws -> [NSTextCheckingResult] {
		let regex = try NSRegularExpression(pattern: regex)
		return regex.matches(in: text, range: NSMakeRange(0, text.count))
	}

	private static func parseTarget(from output: String) throws -> String? {
		let swiftcRegex = ".*/swiftc.*[\\s]+-target[\\s]+([^\\s]*).*"
		if let targetMatch = try match(regex: swiftcRegex, in: output).first {
			return (output as NSString).substring(with: targetMatch.range(at: 1))
		}

		return nil
	}

	private static func parseSourceFiles(from output: String) throws -> Set<String>? {
		let sourceRegex = "(/([^ ]|(?<=\\\\) )*\\.swift(?<!\\\\))"
		let sourceMatches = try match(regex: sourceRegex, in: output)

		return Set(sourceMatches.map {
			(output as NSString).substring(with: $0.range(at: 1)).unescaped()
		}.filter {
			// TODO: lol no this is terrible
			!$0.contains("/build/")
		})
	}

	private static func getArguments(for path: String, target: String, with config: Configuration) -> [String] {
		let filename = ((path as NSString).lastPathComponent as String)

		var arguments = [
			"-sdk",
			config.sdkName,
			"swiftc",
			//        "-emit-sil",
			"-emit-ir",
			"-g",
			"-o", "/Users/thedderwick/Desktop/sil/\(filename).ll",
			"-F", config.frameworkPath,
			"-target", target,
			"-module-name", config.productModuleName,
			path
		]

		// HACK: see https://github.com/apple/swift/issues/55127
		// TODO: improve this check by looking for @main or other attributes
		if filename == "AppDelegate.swift" || filename == "ContentView.swift" {
			arguments.append("-parse-as-library")
		}

		return arguments
	}

	private static func emitIR(with arguments: [String]) throws -> String? {
		var arguments = arguments
		arguments.append("-emit-ir")

		return try Process.runShell(xcrun, arguments: arguments)
	}

	private static func emitSIL(with arguments: [String]) throws -> String? {
		var arguments = arguments
		arguments.append("-emit-sil")

		return try Process.runShell(xcrun, arguments: arguments)
	}
}
