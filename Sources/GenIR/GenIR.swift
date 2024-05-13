import Foundation
import ArgumentParser
import Logging
import PBXProjParser
import PIFSupport

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

	@Flag(help: "Output the dependency graph as .dot files to the output directory - debug only")
	var dumpDependencyGraph = false

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

		// Version 0.2.x and below allowed the output folder to be any arbitrary folder.
		// Docs said to use 'IR' inside an xcarchive. For backwards compatibility, if we have an xcarchive path with an IR
		// folder, remove the IR portion
		if xcarchivePath.filePath.hasSuffix("IR") {
			xcarchivePath.deleteLastPathComponent()
		}

		guard xcarchivePath.lastPathComponent.hasSuffix("xcarchive") else {
			throw ValidationError("xcarchive path must have an .xcarchive extension. Found \(xcarchivePath.lastPathComponent)")
		}

		if !FileManager.default.directoryExists(at: xcarchivePath) {
			throw ValidationError("Archive path doesn't exist: \(xcarchivePath.filePath)")
		}
	}

	mutating func run() throws {
		try run(
			project: projectPath,
			log: logPath,
			archive: xcarchivePath,
			level: logger.logLevel,
			dryRun: dryRun,
			dumpDependencyGraph: dumpDependencyGraph
		)
	}

	mutating func run(
		project: URL,
		log: String,
		archive: URL,
		level: Logger.Level,
		dryRun: Bool,
		dumpDependencyGraph: Bool
	) throws {
		let output = archive.appendingPathComponent("IR")
		// let project = try ProjectParser(path: project, logLevel: level)
		// var targets = Targets(for: project)

		let log = try logParser(for: log)
		try log.parse()

		// Find and parse the PIF cache
		let pifCache = try PIFCache(buildCache: log.buildCachePath)

		let buildCacheManipulator = try BuildCacheManipulator(
			buildCachePath: log.buildCachePath,
			buildSettings: log.settings,
			archive: archive,
			dryRun: dryRun
		)

		let targets = Target.targets(from: pifCache.targets, with: log.targetCommands)

		let runner = CompilerCommandRunner(
			output: output,
			buildCacheManipulator: buildCacheManipulator,
			dryRun: dryRun
		)
		try runner.run(targets: targets)

		let provider = PIFDependencyProvider(targets: targets, cache: pifCache)
		let builder = DependencyGraphBuilder(provider: provider, values: targets)
		let graph = builder.graph

		if dumpDependencyGraph {
			do {
				try graph.toDot(output.appendingPathComponent("graph.dot").filePath)
			} catch {
				logger.error("toDot error: \(error)")
			}
		}

		let postprocessor = try OutputPostprocessor(
			archive: archive,
			output: output,
			graph: graph,
			targets: targets
		)

		try postprocessor.process()
	}

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
