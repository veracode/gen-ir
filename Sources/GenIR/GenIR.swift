import Foundation
import ArgumentParser
import Logging

/// Global logger object
var logger = Logger(label: Bundle.main.bundleIdentifier ?? "com.veracode.gen-ir", factory: StdOutLogHandler.init)

let programName = CommandLine.arguments.first!

/// Command to emit LLVM IR from an Xcode build log
@main
// swiftlint:disable:next type_body_length 
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
		var returnCode = 0

		print("Starting gen-ir, version \(Versions.version)")

		print("Arguments:")
		print("\tproject: \(projectPath!)")
		print("\tbuild log: \(logPath)")
		print("\tarchive: \(xcarchivePath)")
		print("\tIR path: \(outputPath)")
		print("\tlog-level: \(logger.logLevel)")
		print("\tdry-run: \(dryRun)")

		do {
			try run(
				project: projectPath,
				log: logPath,
				archive: xcarchivePath,
				output: outputPath,
				dryRun: dryRun
			)
		} catch {
			returnCode = 1
			print("ERROR, \(error)")
		}

		let endTime = Date()
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		print("Start: \(dateFormatter.string(from: startTime))")
		print("End:   \(dateFormatter.string(from: endTime))")
		let runtime = String(format: "%.3f", endTime.timeIntervalSince(startTime))
		print("Runtime: \(runtime) seconds")

		if returnCode == 0 {
			print("SUCCESS")
		} else {
			print("FAILURE")
			throw ExitCode(1)
		}
	}

	// swiftlint:disable:next function_body_length cyclomatic_complexity
	mutating func run(project: URL, log: String, archive: URL, output: URL, dryRun: Bool) throws {
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
		for prj in genProjects {
			logger.info("Project: \(prj.name) [\(prj.guid)]")

			for tgt in (prj.targets ?? []) {
				logger.info("  - Target: \(tgt.nameForOutput) [\(tgt.productReference?.name ?? String())] [\(tgt.type)] [\(tgt.guid)]")

				for dep in (tgt.dependencyTargets ?? []) {
					logger.info("    - Dependency: \(dep.nameForOutput) [\(dep.guid)]")
				}
			}
		}

		// archiveTargets are read from the .xcarchive - tells us what we're building
		let archiveTargetList: [String] = try getArchiveTargets(archivePath: archive)
		logger.info("")		// empty line for spacing
		for tgt in genTargets where archiveTargetList.contains(tgt.value.nameForOutput) {
			tgt.value.archiveTarget = true
			logger.info("Archive Target: \(tgt.value.nameForOutput)")
		}

		logger.info("\nHandling special-case frameworks")
		for tgt in genTargets where tgt.value.archiveTarget == true {
			try getArchiveFrameworks(archivePath: archive, target: tgt.value, allTargets: genTargets)
		}

		// we start at the root targets, and build the full graph from there
		// and we already have the first level dependencies so we could determine if this target is a root
		logger.info("\nBuilding Dependency Graph")
		for tgt in genTargets where tgt.value.archiveTarget == true {
			logger.info("Starting at root: \(tgt.value.nameForOutput) [\(tgt.value.type)] [\(tgt.value.guid)]")

			// if the target is an app (common case)
			if tgt.value.type == GenTarget.TargetType.applicationTarget {

				// handle the frameworks
				// all this funky processing to handle nested frameworks and re-locating them up to the app
				var moreToProcess: Bool
				repeat {
					moreToProcess = false
					for frTarget in (tgt.value.frameworkTargets ?? []) {
						// swiftlint:disable:next for_where
						if self.findDependencies(root: frTarget, child: frTarget, app: tgt.value) == true {
							moreToProcess = true
						}
					}
				} while (moreToProcess == true)

				// this will handle all the direct/static (non-framework dependencies)
				for depTarget in (tgt.value.dependencyTargets ?? []) {
					// if something exists as both a framework and a dep, prefer the framework
					if (tgt.value.frameworkTargets?.contains(depTarget) ?? false) == false {
						self.findDependencies(root: tgt.value, child: depTarget, app: tgt.value)
					} else {
						tgt.value.dependencyTargets?.remove(depTarget)
						logger.debug("Removed \(depTarget.nameForOutput) from dependency list - exists as a frameworkTarget")
					}
				}
			} else if tgt.value.type == GenTarget.TargetType.frameworkTarget {
				// target is a framework (possible, just not common)

				// iOS does not allow nested frameworks, so remove the dependency
				for depTarget in (tgt.value.dependencyTargets ?? [])
					where depTarget.type == GenTarget.TargetType.frameworkTarget {
						tgt.value.dependencyTargets?.remove(depTarget)
						logger.debug("Removed \(depTarget.nameForOutput) from dependency list - no nested frameworks")
				}

				// TODO: ?? if there is an embedded framework (i.e., it exists in the frameworkTargets list)
				// promote the embedded framework to top level, and handle it's dependencies?

			} else {
				logger.error("\(tgt.value.nameForOutput) is not an App or Framework")
			}
		}

		logger.info("\nDependency Graph:")
		for tgt in genTargets where tgt.value.archiveTarget == true {
			logger.info("  Root target: \(tgt.value.nameForOutput) [\(tgt.value.type)] [\(tgt.value.guid)] [src: \(tgt.value.hasSource)]")

			for dep in tgt.value.dependencyTargets ?? [] {
				logger.info("    (d) \(dep.nameForOutput) [\(dep.type)] [\(dep.guid)] [src: \(dep.hasSource)]")
			}

			for frm in tgt.value.frameworkTargets ?? [] {
				logger.info("    (f) \(frm.nameForOutput) [\(frm.type)] [\(frm.guid)] [src: \(frm.hasSource)]")
				for dep in frm.dependencyTargets ?? [] {
					logger.info("        - \(dep.nameForOutput) [\(dep.type)] [\(dep.guid)] [src: \(dep.hasSource)]")
				}
			}
		}

		// parse the build log to get the compiler commands 
		let log = try logParser(for: log, projects: genProjects)
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

	/// Gets an `XcodeLogParser` for a path
	/// - Parameter path: The path to a file on disk containing an Xcode build log, or `-` if stdin should be read
	/// - Returns: An `XcodeLogParser` for the given path
	private func logParser(for path: String, projects: [GenProject]) throws -> XcodeLogParser {
		var input: [String] = []

		if path == "-" {
			input = try readStdin()
		} else {
			input = try String(contentsOf: path.fileURL).components(separatedBy: .newlines)
		}

		return XcodeLogParser(log: input, projects: projects)
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

		for line in input where line.contains("Build description path: ") {
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
	private func findDependencies(root: GenTarget, child: GenTarget, app: GenTarget) -> Bool {
		for dependency in child.dependencyTargets ?? [] {
			// since iOS (and watchOS and tvOS) don't support nested frameworks, we need to 
			// move them to be children of the app itself
			if dependency.type == GenTarget.TargetType.frameworkTarget {
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
		let frameworksPath = productPath.appendingPathComponent("Library").appendingPathComponent("Frameworks")
		// other ??

		var roots: [String] = []
		let fmgr = FileManager.default

		do {
			var files: [URL]

			// application(s)
			if fmgr.directoryExists(at: applicationPath) {
				files = try fmgr.contentsOfDirectory(at: applicationPath, includingPropertiesForKeys: nil)

				for file in files {
					roots.append(file.lastPathComponent)
				}
			}

			// framework(s)
			if fmgr.directoryExists(at: frameworksPath) {
				files = try fmgr.contentsOfDirectory(at: frameworksPath, includingPropertiesForKeys: nil)

				for file in files {
					roots.append(file.lastPathComponent)
				}
			}
		} catch {
			throw "Error getting target list from archive.  Is the archive \(archivePath.filePath) valid?"
		}

		return roots
	}

	//
	//
	// swiftlint:disable:next function_body_length cyclomatic_complexity
	private func getArchiveFrameworks(archivePath: URL, target: GenTarget, allTargets: [String: GenTarget ]) throws {
		let productPath = archivePath.appendingPathComponent("Products")
		let applicationPath = productPath.appendingPathComponent("Applications")
		// other ??

		// nested frameworks are not allowed in iOS
		if target.type == GenTarget.TargetType.frameworkTarget {
			logger.debug("\(target.nameForOutput) is a framework, skipping")
			return
		}

		let fmgr = FileManager.default

		do {
			let apps = try fmgr.contentsOfDirectory(at: applicationPath, includingPropertiesForKeys: nil)

			for app in apps where app.lastPathComponent == target.nameForOutput {
				logger.info(" for \(app.lastPathComponent)")

				logger.info("  checking for frameworks")
				let frameworkPath = app.appendingPathComponent("Frameworks")

				if !fmgr.directoryExists(at: frameworkPath) {
					logger.info("  no frameworks found")
					return
				}

				let appFrameworks = try fmgr.contentsOfDirectory(at: frameworkPath, includingPropertiesForKeys: nil)

				for frm in appFrameworks where frm.pathExtension == "framework" {
					// make sure this exits as a framework of the app, not a static dependency
					let frName = frm.lastPathComponent
					let frBasename = frm.lastPathComponent.deletingPathExtension()

					/* this first case handles Swift Packages that are linked as frameworks */

					// TODO: can I trust the name, or better to use the 
					// 'dynamicTargetVariantGuid' from the PifCache Target files
					for dep in target.dependencyTargets ?? [] {
						if frBasename == dep.name && dep.type == .packageTarget {
							logger.info("  moving \(dep.nameForOutput) [\(dep.type)] [\(dep.guid)] to the framework list")
							target.frameworkTargets?.insert(dep)
							target.dependencyTargets?.remove(dep)
						}
					}

					/* this second case handles frameworks that don't show up as dependencies (usually CocoaPods) */
					for tgt in allTargets where tgt.value.nameForOutput == frName {
						if target.frameworkTargets?.insert(tgt.value).inserted ?? false {
							logger.info("  adding \(tgt.value.nameForOutput) [\(tgt.value.type)] [\(tgt.value.guid)] to the framework list")
						}
					}
				}

				logger.info("  checking for plugins")
				let pluginPath = app.appendingPathComponent("Plugins")

				if !fmgr.directoryExists(at: pluginPath) {
					logger.info("  no plugins found")
					return
				}

				let appPlugins = try fmgr.contentsOfDirectory(at: pluginPath, includingPropertiesForKeys: nil)

				for plg in appPlugins where plg.pathExtension == "appex" {
					// make sure this exits as a framework of the app, not a static dependency
					// let plgName = plg.lastPathComponent
					let plgBasename = plg.lastPathComponent.deletingPathExtension()

					// TODO: can I trust the name, or better to use the 
					// 'dynamicTargetVariantGuid' from the PifCache Target files
					for dep in target.dependencyTargets ?? [] {
						if plgBasename == dep.name && dep.type == .extensionTarget {
							logger.info("  moving \(dep.nameForOutput) [\(dep.type)] [\(dep.guid)] to the framework list")
							target.frameworkTargets?.insert(dep)
							target.dependencyTargets?.remove(dep)
						}
					}
				}
			}
		} catch {
			throw "Error handling special frameworks list for \(target.nameForOutput)"
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
// swiftlint:disable:next file_length
}
