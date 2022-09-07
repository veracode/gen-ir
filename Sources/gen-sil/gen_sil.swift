import Foundation

// Heavily inspired by https://blog.digitalrickshaw.com/2016/03/14/dumping-the-swift-ast-for-an-ios-project-part-2.html
@main
public struct gen_sil {
	public static func main() throws {
		var environment = ProcessInfo.processInfo.environment
		let config: Configuration
		
		do {
			config = try Configuration(from: environment)
		} catch Configuration.Error.configurationError(let error) {
			print("Configuration error: \(error)")
			exit(EXIT_FAILURE)
		} catch {
			print("Unexpected error: \(error)")
			exit(EXIT_FAILURE)
		}

		guard config.shouldSkipGenSil == false else {
			// HACK: Because the new Xcode build system doesn't _yet_ support -dry-run
			// we essentially have to compile twice. Have a env flag to stop the second run
			// TODO: this will need to change - is there some metadata (or xcodeproj) we can parse for the file list?
			print("============ should skip is set - skipping run ==============")
			exit(EXIT_SUCCESS)
		}
		
		// we now want to skip any new invocations of this tool
		environment["SHOULD_SKIP_GEN_SIL"] = "1"
		print("running xcodebuild from gen_sil")
		
		let coordinator = XcodeCoordinator()
		
		guard let archiveOutput = try coordinator.archive(with: config, environment: environment) else {
			print("Failed to get output from xcodebuild archive command")
			exit(EXIT_FAILURE)
		}

		// TODO: is this ever different from the target in the environment? If not, get rid of this
		guard let target = try coordinator.parseTarget(from: archiveOutput) else {
			print("Failed to find target from output: ")
			archiveOutput.split(separator: "\n").forEach { print($0) }
			exit(EXIT_FAILURE)
		}
		
		print("Found target: \(target)")
		
		guard let sourceFiles = try coordinator.parseSourceFiles(from: archiveOutput) else {
			print("Failed to find source files from output: ")
			archiveOutput.split(separator: "\n").forEach { print($0) }
			exit(EXIT_FAILURE)
		}
		
		print("------- source files ----------")
		print(sourceFiles)
		print("-------------------------------")
		
		// emit IR for each source file
		sourceFiles.forEach { sourceFile in
			do {
				if let result = try coordinator.emit(.ir, for: sourceFile, target: target, config: config) {
					print("result: \(result)")
				}
			} catch {
				print("Failed to emit for file: \(sourceFile), error: \(error)")
			}
		}
		
		exit(EXIT_SUCCESS)
	}
}
