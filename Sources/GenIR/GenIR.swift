import Foundation
import ArgumentParser
import Logging
import PBXProjParser

/// Global logger object
var logger = Logger(label: Bundle.main.bundleIdentifier ?? "com.veracode.gen-ir", factory: StdOutLogHandler.init)

let programName = CommandLine.arguments.first!

/// Command to emit LLVM IR from an Xcode build log
@main
struct IREmitterCommand: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "",
		abstract: "Consumes an Xcode build log, and outputs LLVM IR, in the bitstream format, to the folder specified",
		discussion:
		"""
		This can either be done via a file, or via stdin. You may have to redirect stderr to stdin before piping it to this \
		tool.

		This tool requires a full Xcode build log in order to capture all files in the project. If this is not provided, \
		you may notice that not all modules are emitted.

		To ensure this, run `xcodebuild clean` first before you `xcodebuild build` command.

		Example with build log:
			$ xcodebuild clean && xcodebuild build -project MyProject.xcodeproj -configuration Debug -scheme MyScheme > \
		log.txt
			$ \(programName) log.txt output_folder/ --project-path MyProject.xcodeproj

		Example with pipe:
			$ xcodebuild clean && xcodebuild build -project MyProject.xcodeproj -configuration Debug -scheme MyScheme 2>&1 \
		| \(programName) - output_folder/ --project-path MyProject.xcodeproj
		""",
		version: "v\(Versions.version)"
	)

	/// Path to an Xcode build log, or `-` if build log should be read from stdin
	@Argument(help: "Path to a full Xcode build log. If `-` is provided, stdin will be read")
	var logPath: String

	/// Path to the xcarchive to write the LLVM BC files to
	@Argument(help: "Path to the xcarchive associated with the build log")
	var xcarchivePath: URL

	/// Scheme name, needed to find the build manifest
	@Option(help: "Name of the scheme used when building")
	var scheme: String

	/// Path to xcodeproj or xcworkspace file
	@Option(help: "Path to your Xcode Project or Workspace file")
	var projectPath: URL!

	/// Enables enhanced debug logging
	@Flag(help: "Enables debug level logging")
	var debug = false

	/// Reduces log noise
	@Flag(help: "Reduces log noise by suppressing xcodebuild output when reading from stdin")
	var quieter = false

	@Flag(help: "Runs the tool without outputting IR to disk (i.e. leaving out the compiler command runner stage)")
	var dryRun = false

	/// Path to write IR to
	private lazy var outputPath: URL = xcarchivePath.appendingPathComponent("IR")

	mutating func validate() throws {
		if debug {
			logger.logLevel = .debug
		}

		// Version 0.2.x and below didn't require a project. Attempt to default this value if we can
		if projectPath == nil {
			projectPath = try findProjectPath()
		}

		if !FileManager.default.fileExists(atPath: projectPath.filePath) {
			throw ValidationError("Project doesn't exist at path: \(projectPath.filePath)")
		}

		// Version 0.2.x and below allowed the output folder to be any artibrary folder.
		// Docs said to use 'IR' inside an xcarchive. For backwards compatibility, if we have an xcarchive path with an IR
		// folder, remove the IR portion
		if xcarchivePath.filePath.hasSuffix("IR") {
			xcarchivePath.deleteLastPathComponent()
		}

		guard xcarchivePath.lastPathComponent.hasSuffix("xcarchive") else {
			throw ValidationError("xcarchive path must have an .xcarchive extension. Found \(xcarchivePath.lastPathComponent)")
		}

		if !FileManager.default.directoryExists(at: outputPath) {
			logger.debug("Output path doesn't exist, creating \(outputPath)")
			do {
				try FileManager.default.createDirectory(at: outputPath, withIntermediateDirectories: true)
			} catch {
				throw ValidationError("Failed to create output directory with error: \(error)")
			}
		}
	}

	mutating func run() throws {
		try run(
			project: projectPath,
			log: logPath,
			scheme: scheme,
			archive: xcarchivePath,
			output: outputPath,
			level: logger.logLevel,
			dryRun: dryRun
		)
	}

	// swiftlint:disable function_parameter_count
	mutating func run(project: URL, log: String, scheme: String, archive: URL, output: URL, level: Logger.Level, dryRun: Bool) throws {
		logger.debug("running...")

		var genTargets: [GenTarget] = [GenTarget]()
		var genProjects: [GenProject] = [GenProject]()

		// find the PIFCache location
		let pifCacheHandler = PifCacheHandler(project: project, scheme: scheme)

		// parse the PIF cache files and create a list of projects and targets
		pifCacheHandler.getTargets(targets: &genTargets)
		pifCacheHandler.getProjects(targets: genTargets, projects: &genProjects)
		
		
		
		
		
		
		//let project = try ProjectParser(path: project, logLevel: level)
		//var targets = Targets(for: project)

		let log = try logParser(for: log)
		//try log.parse(&targets)

		let buildCacheManipulator = try BuildCacheManipulator(
			buildCachePath: log.buildCachePath,
			buildSettings: log.settings,
			archive: archive
		)

		let runner = CompilerCommandRunner(
			output: output,
			buildCacheManipulator: buildCacheManipulator,
			dryRun: dryRun
		)
		//try runner.run(targets: targets)

		let postprocessor = try OutputPostprocessor(archive: archive, output: output)
		//try postprocessor.process(targets: &targets)
	}
	// swiftlint:enable function_parameter_count

	/// Gets an `XcodeLogParser` for a path
	/// - Parameter path: The path to a file on disk containing an Xcode build log, or `-` if stdin should be read
	/// - Returns: An `XcodeLogParser` for the given path
	private func logParser(for path: String) throws -> XcodeLogParser {
		var input: [String] = []

		if path == "-" {
			input = try readStdin()
		} else {
			input = try String(contentsOf: path.fileURL).components(separatedBy: .newlines)
		}

		return XcodeLogParser(log: input)
	}

	/// Reads stdin until an EOF is found
	/// - Returns: An array of Strings representing stdin split by lines
	private func readStdin() throws -> [String] {
		logger.info("Collating input via pipe")

		var results = [String]()

		while let line = readLine() {
			if !quieter {
				print(line) // shows user that build is happening
			}
			results.append(line)

			if line.contains("** ARCHIVE FAILED **") {
				throw ValidationError("xcodebuild failed to archive app, please correct any compilation errors and try again")
			}
		}

		if !quieter {
			print("\n\n")
		}

		logger.info("Finished reading from pipe")

		return results
	}
}

extension IREmitterCommand {
	/// Attempt to automatically determine the Xcode workspace or project path
	/// - Returns: the path to the first xcworkspace or xcodeproj found in the current directory
	private func findProjectPath() throws -> URL {
		let cwd = FileManager.default.currentDirectoryPath.fileURL
		// First, xcworkspace, then xcodeproj
		let xcworkspace = try FileManager.default.directories(at: cwd, recursive: false)
			.filter { $0.pathExtension == "xcworkspace" }

		if xcworkspace.count == 1 {
			return xcworkspace[0]
		}

		let xcodeproj = try FileManager.default.directories(at: cwd, recursive: false)
			.filter { $0.pathExtension == "xcodeproj" }

		if xcodeproj.count == 1 {
			return xcodeproj[0]
		}

		throw ValidationError(
			"""
			Couldn't automatically determine path to xcodeproj or xcworkspace. Please use --project-path to provide it.
			"""
		)
	}
}

extension URL: ExpressibleByArgument {
	public init?(argument: String) {
		self = argument.fileURL.absoluteURL
	}
}
