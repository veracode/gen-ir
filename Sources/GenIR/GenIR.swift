import Foundation
import ArgumentParser
import Logging
import PIFSupport
import DependencyGraph
import LogHandlers

/// The name of the program
let programName = CommandLine.arguments.first!

/// Command to emit LLVM IR from an Xcode build log
@main struct IREmitterCommand: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "",
		abstract: "Consumes an Xcode build log, and outputs LLVM IR, in the bitstream format, to the folder specified",
		discussion:
        """
        This can either be done via a file, or via stdin. You may have to redirect stderr to stdin before piping it to this \
        tool.

        This tool requires a full Xcode build log in order to capture all files in the project. If this is not provided, you may notice \
        that not all modules are emitted.

        To ensure this, run `xcodebuild clean` first before you `xcodebuild build` command.

        Example with build log:
        	$ xcodebuild clean && xcodebuild build -project MyProject.xcodeproj -configuration Debug -scheme MyScheme \
        DEBUG_INFOMATION_FORMAT=dwarf-with-dsym ENABLE_BITCODE=NO > log.txt
                $ \(programName) log.txt x.xcarchive

        Example with pipe:
        	$ xcodebuild clean && xcodebuild build -project MyProject.xcodeproj -configuration Debug -scheme MyScheme \
        DEBUG_INFOMATION_FORMAT=dwarf-with-dsym ENABLE_BITCODE=NO 2>&1 | \(programName) - x.xcarchive

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
	@Option(help: "DEPRECATED: This Option is deprecated and will go away in a future version.")
	var projectPath: URL?

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

	@Option(help: "Path to PIF cache. Use this in place of what is in the Xcode build log")
	var pifCachePath: URL?

	mutating func validate() throws {
		// This will run before run() so set this here
		if debug {
			logger.logLevel = .debug
		}

		if projectPath != nil {
			logger.warning("--project-path has been deprecated and will go away in a future version. Please remove it from your invocation.")
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
			log: logPath,
			archive: xcarchivePath,
			level: logger.logLevel,
			dryRun: dryRun,
			dumpDependencyGraph: dumpDependencyGraph
		)
	}

	mutating func run(
		log: String,
		archive: URL,
		level: Logger.Level,
		dryRun: Bool,
		dumpDependencyGraph: Bool,
		pifCachePath: URL? = nil
	) throws {
		logger.logLevel = level
        logger.info(
            """

            Gen-IR v\(IREmitterCommand.configuration.version)
                log: \(log)
                archive: \(archive.filePath)
                level: \(level)
                dryRun: \(dryRun)
                dumpDependencyGraph: \(dumpDependencyGraph)
                pifCache: \(pifCachePath?.filePath ?? "not provided")
            """)
		let output = archive.appendingPathComponent("IR")

		let log = try logParser(for: log)
		try log.parse()

		// Find and parse the PIF cache
		let pifCachePath = pifCachePath ?? URL(fileURLWithPath: log.buildCachePath.filePath)
		logger.info("PIF location is: \(pifCachePath)")
		let pifCache = try PIFCache(buildCache: pifCachePath)

		let targets = pifCache.projects.flatMap { project in
			project.targets.compactMap { Target(from: $0, in: project) }
		}.filter { !$0.isTest }
        logger.debug("Project non-test targets: \(targets.count)")

		let targetCommands = log.commandLog.reduce(into: [TargetKey: [CompilerCommand]]()) { commands, entry in
			commands[entry.target, default: []].append(entry.command)
		}

		let builder = DependencyGraphBuilder<PIFDependencyProvider, Target>(
			provider: .init(targets: targets, cache: pifCache),
			values: targets
		)
		let graph = builder.graph

		if dumpDependencyGraph {
			do {
				try graph.toDot(output
					.deletingLastPathComponent()
					.appendingPathComponent("graph.dot")
					.filePath
				)
			} catch {
				logger.error("toDot error: \(error)")
			}
		}

		let buildCacheManipulator = try BuildCacheManipulator(
			buildCachePath: log.buildCachePath,
			buildSettings: log.settings,
			archive: archive,
			dryRun: dryRun
		)

		let tempDirectory = try FileManager.default.temporaryDirectory(named: "gen-ir-\(UUID().uuidString)")
		defer { try? FileManager.default.removeItem(at: tempDirectory) }
		logger.info("Using temp directory as working directory: \(tempDirectory)")

		let runner = CompilerCommandRunner(
			output: tempDirectory,
			buildCacheManipulator: buildCacheManipulator,
			dryRun: dryRun
		)
        logger.debug("Targets to run: \(targets.count)")
		try runner.run(targets: targets, commands: targetCommands)

		let postprocessor = try OutputPostprocessor(
			archive: archive,
			build: tempDirectory,
			graph: graph
		)

		try postprocessor.process()
        logger.info("\n\n** Gen-IR SUCCEEDED **\n\n")
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

		return results
	}
}

extension URL: ExpressibleByArgument {
	public init?(argument: String) {
		self = argument.fileURL.absoluteURL
	}
}
