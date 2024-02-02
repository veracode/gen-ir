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
		let  startTime = Date()

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

		let endTime = Date()
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		logger.info("Start: \(dateFormatter.string(from: startTime))")
		logger.info("End:   \(dateFormatter.string(from: endTime))")
		let runtime = String(format: "%.3f", endTime.timeIntervalSince(startTime))
		logger.info("Runtime: \(runtime) seconds")
	}

	// swiftlint:disable function_parameter_count
	mutating func run(project: URL, log: String, archive: URL, output: URL, level: Logger.Level, dryRun: Bool) throws {
		logger.debug("running...")

		var genTargets = [String: GenTarget]()		// dict of all the targets, using guid as the key
		var genProjects: [GenProject] = [GenProject]()

		// find the PIFCache location
		let pifCacheLocation = try findPifCache(logFile: log)
		let pifCacheHandler = PifCacheHandler(pifCache: pifCacheLocation)

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

		// archiveTargets are read from the .xcarchive - tells us what we're building
		let archiveTargetList: [String] = try getArchiveTargets(archivePath: archive)
		for t in genTargets {
			if archiveTargetList.contains(t.value.nameForOutput) {
				t.value.archiveTarget = true
				logger.info("\nArchive Target(s): \(t.value.nameForOutput)")
			}
		}



		logger.info("\nHandling special-case frameworks")
		for t in genTargets {
			if t.value.archiveTarget == true {
				try getArchiveFrameworks(archivePath: archive, target: t.value, allTargets: genTargets)
			}
		}



		// we start at the root targets, and build the full graph from there
		// and we already have the first level dependencies so we could determine if this target is a root
		logger.info("\nBuilding Dependency Graph")
		for t in genTargets {
			if t.value.archiveTarget == true {
				logger.info("Starting at root: \(t.value.nameForOutput) [\(t.value.type)] [\(t.value.guid)]")

				// handle the frameworks
				// all this funky processing to handle nested frameworks and re-locating them up to the app
				var moreToProcess: Bool
				repeat {
					moreToProcess = false
					for frTarget in (t.value.frameworkTargets ?? []) {
						if self.findDependencies(root: frTarget, child: frTarget, app: t.value) == true {
							moreToProcess = true
						} else {
							frTarget.dependenciesProcessed = true
						}
					}
				} while (moreToProcess == true)

				// this will handle all the direct/static (non-framework dependencies)
				for depTarget in (t.value.dependencyTargets ?? []) {
					// if something exists as both a framework and a dep, prefer the framework
					if (t.value.frameworkTargets?.contains(depTarget) ?? false) == false {
						self.findDependencies(root: t.value, child: depTarget, app: t.value)
					} else {
						t.value.dependencyTargets?.remove(depTarget)
					}
				}
			}
		}

		// logger.info("\nHandling special-case frameworks")
		// for t in genTargets {
		// 	if t.value.archiveTarget == true {
		// 		try getArchiveFrameworks(archivePath: archive, target: t.value, allTargets: genTargets)
		// 	}
		// }

		logger.info("\nDependency Graph:")
		for t in genTargets {
			if t.value.archiveTarget == true {
				logger.info("  Root target: \(t.value.nameForOutput) [\(t.value.type)] [build=\(t.value.archiveTarget)] [\(t.value.guid)]")

				for d in t.value.dependencyTargets ?? [] {
					logger.info("    (d) \(d.nameForOutput) [\(d.type)] [\(d.guid)]")
				}

				for f in t.value.frameworkTargets ?? [] {
					logger.info("    (f) \(f.nameForOutput) [\(f.type)] [\(f.guid)]")
					for d in f.dependencyTargets ?? [] {
						logger.info("        - \(d.nameForOutput) [\(d.type)] [\(d.guid)]")
					}
				}
			}
		}

		// parse the build log to get the compiler commands 
		let log = try logParser(for: log, targets: genTargets, projects: genProjects)
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
	// TODO: merge with the logParser, as it's doing the same thing to find the buildCache
	private func findPifCache(logFile: String) throws -> URL {
		var input: [String] = []
		var pifCacheDir: URL

		if logFile == "-" {
			input = try readStdin()
		} else {
			input = try String(contentsOf: logFile.fileURL).components(separatedBy: .newlines)
		}

		for line in input {
			if line.contains("Build description path: ") {
				guard let startIndex = line.firstIndex(of: ":") else { continue }

				let stripped = line[line.index(after: startIndex)..<line.endIndex].trimmingCharacters(in: .whitespacesAndNewlines)

				let derivedDataDir = String(stripped).fileURL
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent()

				pifCacheDir = derivedDataDir.appendingPathComponent("Build/Intermediates.noindex/XCBuildData/PIFCache")

				// validate PIF Cache dir exists
				if !FileManager.default.fileExists(atPath: pifCacheDir.path) {
					throw ValidationError("PIF Cache doesn't exist at: \(pifCacheDir)")
				}

				logger.info("Found PIFCache at: \(pifCacheDir)")

				return pifCacheDir
			}
		}

		throw ValidationError("Unable to find PIF Cache")
	}

	//
	//
	@discardableResult
	private func findDependencies(root: GenTarget, child: GenTarget, app: GenTarget) -> Bool{
		for dependency in child.dependencyTargets ?? [] {
			// since iOS (and watchOS and tvOS) don't support nested frameworks, we need to 
			// move them to be children of the app itself
			if(dependency.type == GenTarget.TargetType.Framework) {
				app.frameworkTargets?.insert(dependency)
				child.dependencyTargets?.remove(dependency)
				return true
			} else {
				root.dependencyTargets?.insert(dependency)
			}

			// recurse
			self.findDependencies(root: root, child: dependency, app: app)
		}

		return false
	}

	//
	//
	private func getArchiveTargets(archivePath: URL) throws -> [String] {
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
			throw "Error getting target list from archive"
		}

		return roots
	}

	//
	//
	private func getArchiveFrameworks(archivePath: URL, target: GenTarget, allTargets: [String : GenTarget ]) throws {
		let productPath = archivePath.appendingPathComponent("Products")
		let applicationPath = productPath.appendingPathComponent("Applications")
		// other ??

		let fm = FileManager.default

		do {
			let apps = try fm.contentsOfDirectory(at: applicationPath, includingPropertiesForKeys: nil)

			for app in apps {
				if(app.lastPathComponent == target.nameForOutput) {
					logger.info(" for \(app.lastPathComponent)")
					let frameworkPath = app.appendingPathComponent("Frameworks")

					if !fm.directoryExists(at: frameworkPath) {
						logger.info("  no frameworks found")
						return
					}

					let appFrameworks = try fm.contentsOfDirectory(at: frameworkPath, includingPropertiesForKeys: nil)

					for fr in appFrameworks {
						if fr.pathExtension == "framework" {

							// make sure this exits as a framework of the app, not a static dependency
							let frName = fr.lastPathComponent
							let frBasename = fr.lastPathComponent.deletingPathExtension()

							/* this first case handles Swift Packages that are linked as frameworks */

							// TODO: can I trust the name, or better to use the 
							// 'dynamicTargetVariantGuid' from the PifCache Target files
							for d in target.dependencyTargets ?? [] {
								if frBasename == d.name && d.type == .Package{
									logger.info("  moving \(d.nameForOutput) [\(d.type)] [\(d.guid)] to the framework list")
									target.frameworkTargets?.insert(d)
									target.dependencyTargets?.remove(d)
								}
							}

							/* this second case handles frameworks that don't show up as dependencies (usually CocoaPods) */
							for tgt in allTargets {
								if tgt.value.nameForOutput == frName {
									if target.frameworkTargets?.insert(tgt.value).inserted ?? false {
										logger.info("  adding \(tgt.value.nameForOutput) [\(tgt.value.type)] [\(tgt.value.guid)] to the framework list")
									}
								}
							}
						}
					}
				}
			}
		} catch {
			throw "Error haddling special frameworks list for \(target.nameForOutput)"
		}
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

// allows us to throw errors with just strings
extension String: LocalizedError {
	public var errorDescription: String? { return self }
}
