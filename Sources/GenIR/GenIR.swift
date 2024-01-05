import Foundation
import ArgumentParser
import Logging
//import PBXProjParser

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

		// delete the old IR directory if it exists (mostly happens in testing) and create a new one
		if FileManager.default.directoryExists(at: outputPath) {
			do {
				try FileManager.default.removeItem(at: outputPath)
			} catch {
				throw ValidationError("Unable to delete outputPath \(outputPath)  Error: \(error)")
			}
		}
		do {
			try FileManager.default.createDirectory(at: outputPath, withIntermediateDirectories: true)
			logger.debug("Creating output/IR directory: \(outputPath)")
		} catch {
			throw ValidationError("Failed to create output directory with error: \(error)")
		}
	}

	mutating func run() throws {
		do {
			try run(
				project: projectPath,
				log: logPath,
				archive: xcarchivePath,
				output: outputPath,
				level: logger.logLevel,
				dryRun: dryRun
			)

			print("SUCCESS")
		} catch {
			print("FAILED, \(error)")
		}
	}

	// swiftlint:disable function_parameter_count
	mutating func run(project: URL, log: String, archive: URL, output: URL, level: Logger.Level, dryRun: Bool) throws {
		logger.debug("running...")

		var genTargets = [String: GenTarget]()		// dict of all the targets, using guid as the key
		var genProjects: [GenProject] = [GenProject]()

		// find the PIFCache location
		let pifCacheHandler = try PifCacheHandler(project: project)

		// parse the PIF cache files and create a list of projects and targets
		try pifCacheHandler.getTargets(targets: &genTargets)
		try pifCacheHandler.getProjects(targets: genTargets, projects: &genProjects)
		
		// print the project/target tree
		// (no need to think about recursion here, as the PIFCache data only shows direct dependencies)
		logger.info("\nProject/Target tree:")
		for p in genProjects {
			logger.info("Project: \(p.name) [\(p.guid)]")

			for t in (p.targets ?? []) {
				logger.info("  - Target: \(t.nameForOutput) [\(t.productReference?.name ?? String())] [\(t.type)] [\(t.guid)]")

				for d in (t.dependencyTargets ?? []) {
					logger.info("    - Dependency: \(d.nameForOutput) [\(d.guid)]")
				}
			}
		}

		var archiveTargetList: [String] = getArchiveTargets(archivePath: archive)
		for t in genTargets {
			if archiveTargetList.contains(t.value.nameForOutput) {
				t.value.archiveTarget = true
				logger.info("\nArchive Target(s): \(t.value.nameForOutput)")
			}
		}

		logger.info("\nRoot Targets:")
		for t in genTargets {
			if t.value.isDependency == false {
				logger.info("\(t.value.nameForOutput) [\(t.value.type)] [build=\(t.value.archiveTarget)] [\(t.value.guid)]")
			}
		}

		// we start at the root targets, and build the full graph from there
		// and we already have the first level dependencies so we could determine if this target is a root
		logger.info("\nBuilding Dependency Graph")
		for t in genTargets {
			if t.value.isDependency == false {
				logger.info("Starting at root: \(t.value.nameForOutput) [\(t.value.type)] [\(t.value.guid)]")

				for childTarget in (t.value.dependencyTargets ?? []) {
					self.findDependencies(root: t.value, child: childTarget)
				}

			}
		}

		logger.info("\nDependency Graph:")
		for t in genTargets {
			if t.value.isDependency == false {
				logger.info("  Root target: \(t.value.nameForOutput) [\(t.value.type)] [build=\(t.value.archiveTarget)] [\(t.value.guid)]")

				for d in t.value.dependencyTargets ?? [] {
					logger.info("    - \(d.nameForOutput) [\(d.type)] [\(d.guid)]")
				}
			}
		}

		// parse the build log to get the compiler commands 
		let log = try logParser(for: log, targets: genTargets, projects: genProjects)
		//try log.parse(&targets)
		try log.parse()

		let buildCacheManipulator = try BuildCacheManipulator(
			buildCachePath: log.buildCachePath,
			buildSettings: log.settings,
			archive: archive
		)

		// run (modified) compiler commands to output bitcode
		let runner = CompilerCommandRunner(
			output: output,
			buildCacheManipulator: buildCacheManipulator,
			dryRun: dryRun
		)
		try runner.run(projects: genProjects)

		//let postprocessor = try OutputPostprocessor(archive: archive, output: output)
		//try postprocessor.process(targets: &targets)
	}
	// swiftlint:enable function_parameter_count

	/// Gets an `XcodeLogParser` for a path
	/// - Parameter path: The path to a file on disk containing an Xcode build log, or `-` if stdin should be read
	/// - Returns: An `XcodeLogParser` for the given path
	private func logParser(for path: String, targets: [String: GenTarget], projects: [GenProject]) throws -> XcodeLogParser {
		var input: [String] = []

		if path == "-" {
			input = try readStdin()
		} else {
			input = try String(contentsOf: path.fileURL).components(separatedBy: .newlines)
		}

		return XcodeLogParser(log: input, targets: targets, projects: projects)
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

	//
	//
	private func findDependencies(root: GenTarget, child: GenTarget) {
		//logger.debug("Finding dependencies for \(child.guid) for root \(root.guid)")

		for dependency in child.dependencyTargets ?? [] {
			// add this to the root
			root.dependencyTargets?.insert(dependency)

			// recurse
			self.findDependencies(root: root, child: dependency)
		}
	}

	//
	//
	private func getArchiveTargets(archivePath: URL) -> [String] {
		let productPath = archivePath.appendingPathComponent("Products")
		let applicationPath = productPath.appendingPathComponent("Applications")
		// Frameworks??
		// other ??

		var roots: [String] = []

		let fm = FileManager.default

		do {
			let files = try fm.contentsOfDirectory(at: applicationPath, includingPropertiesForKeys: nil)

			for file in files {
				roots.append(file.lastPathComponent)
			}
		} catch {
			logger.error("Error getting target list from archive")
			// Error handling
		}

		return roots
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
