//
//  File.swift
//
//
//  Created by Thomas Hedderwick on 27/07/2022.
//

import Foundation
import RegexBuilder

/// Represents the source files, by type, in a project
struct SourceFiles {
	/// Paths of the Swift files in this project
	let swiftFiles: [URL]

	/// Paths of the Objective-C files in this project
	let objcFiles: [URL]
}

/// The Runner for the CLI subcommand.
///
/// Handles the 'running' logic of command, delegating to coordinators for specific actions
public class CLIRunner: Runner {
	private let configuration: CLIConfiguration
	private let coordinator = CLICoordinator()
	private var state: State = .initialized
	private var buildSettings = [String: String]()
	private let xcodeCoordinator = XcodeCoordinator()

	// TODO: make error handling better
	enum Error: Swift.Error {
		case failedToCreate(URL)
		// TODO: pass stdout/stderr to this?
		case shellCommandFailed
		case failedToFindRequiredData(String)
		case keyNotFound(String)
		case projectHasNotBeenBuilt(String)
	}

	enum State: String {
		case initialized
		case fetchingFileList = "Fetching file list"
		case emitting = "Emitting artefacts"
		case parsingOutput = "Parsing output"
		case splittingModules = "Splitting modules"
		case writingOutput = "Writing output"
	}

	public init(input path: XcodeProjectPath, output: URL, scheme: String) throws {
		buildSettings = try xcodeCoordinator.getBuildSettings(for: path, scheme: scheme)

		configuration = try .init(path, output: output, buildSettings: buildSettings, scheme: scheme)
	}

	public init(configuration: CLIConfiguration) {
		self.configuration = configuration
	}

	func run() throws {
		try createDirectory(configuration.output)

		setState(.fetchingFileList)

		let sourceFiles = try getSourceFiles()

		setState(.emitting)

		try emit(files: sourceFiles)
	}

	private func emit(files: SourceFiles) throws {
		/* ObjC Files */
		print("attempting emit for objc files: \(files.objcFiles)")
		let objcIRFiles = try xcodeCoordinator.emit(forObjCFiles: files.objcFiles, config: configuration)

		try objcIRFiles.forEach {
			let outputPath = configuration.output.appendingPathComponent($0.lastPathComponent)
			if FileManager.default.fileExists(atPath: outputPath.filePath) {
				try FileManager.default.removeItem(at: outputPath)
			}
			try FileManager.default.moveItem(at: $0, to: configuration.output.appendingPathComponent($0.lastPathComponent))
		}

		/* Swift files */
		print("attempting emit for swift files: \(files.swiftFiles)")
		let result = try xcodeCoordinator.emit(forSwiftFiles: files.swiftFiles, type: .ir, config: configuration)

		setState(.parsingOutput)

		// TODO: this returns 1 and output to stderr even on success..........
//		guard result.code == 0  else {
//			print("swift emitting failed: \(result.stdout ?? "No stdout")\n\n\(result.stderr ?? "")")
//			throw Error.shellCommandFailed // TODO: fix
//		}

		// the result will have a _lot_ data that will need to be chopped up into individual files
		var output: String
		if let commandOutput = result.stdout {
			output = commandOutput
		} else if let commandOutput = result.stderr {
			output = commandOutput
		} else {
			throw Error.failedToFindRequiredData("Failed to get output for xcodebuild command")
		}

		setState(.splittingModules)

		// TODO: make this more efficient than 'split everything and join it back together'
		let moduleMarker = "; ModuleID = "
		var splitOutput = output.split(separator: "\n")

		// Drop anything before the first module
		if let dropIndex = splitOutput.firstIndex(where: { $0.starts(with: moduleMarker) }) {
			splitOutput = Array(splitOutput.dropFirst(dropIndex))
		}

		// Find the offsets of module markers
		let indicies = splitOutput
			.enumerated()
			.compactMap { (index, item) in
				return item.starts(with: moduleMarker) ? index : nil
			}

		guard indicies.count >= 1 else {
			print(splitOutput.joined(separator: "\n"))
			throw Error.failedToFindRequiredData("Failed to find module markers in output")
		}

		var moduleContents = [String]()

		if indicies.count == 1 {
			// only one module found, dump the entire thing
			moduleContents.append(splitOutput.joined(separator: "\n"))
		} else {
			var current = indicies.first! // safe: we know at least one index exists

			for next in indicies {
				if current == next { continue }

				let range = current...next
				current = next.advanced(by: 1)

				moduleContents.append(splitOutput[range].joined(separator: "\n"))
			}

			// the last module will be whatever is left from the current index to the end of the array
			if current != splitOutput.count {
				let range = current...(splitOutput.count - 1)
				moduleContents.append(splitOutput[range].joined(separator: "\n"))
			}
		}

		setState(.writingOutput)

		for (index, item) in moduleContents.enumerated() {
			// TODO: Investigate getting file name or something useful as the module ID 
			let filePath = configuration.output.appendingPathComponent("\(index).ll")
			try item.data(using: .utf8)?.write(to: filePath)
		}
	}

	private func setState(_ state: State) {
		self.state = state
		print("[+] \(state.rawValue)")
	}

	private func createDirectory(_ path: URL) throws {
		do {
			try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
		} catch {
			throw Error.failedToCreate(path)
		}
	}

	private func getBuildSetting(_ key: XcodeBuildSettingsKeys) throws -> String {
		guard let value = buildSettings[key.rawValue] else {
			throw Error.keyNotFound("Failed to find \(key.rawValue) in build settings")
		}

		return value
	}

	private func getObjectsPath() throws -> URL {
		guard let objRoot = buildSettings["OBJROOT"]?.fileURL else {
			throw Error.keyNotFound("Failed to find OBJROOT in build settings")
		}

		func getBuildDirectory(at url: URL) throws -> URL? {
			try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
				.filter { $0.lastPathComponent.hasSuffix("\(configuration.targetName).build") }
				.first
		}

		guard let buildDirectory = try getBuildDirectory(at: objRoot) else {
			// TODO: nice to have: build the project for the user
			throw Error.failedToFindRequiredData("Failed to find required build folders. It is required that the current version of the project has been built in debug mode targeting iOS")
		}

		let name = buildDirectory.lastPathComponent

		let objectsPath: URL

		if #available(macOS 13.0, *) {
			objectsPath = buildDirectory
				.appending(path: "Debug-iphoneos")
				.appending(path: name)
				.appending(path: "Objects-normal")
				.appending(path: "arm64")
		} else {
			objectsPath = buildDirectory
				.appendingPathComponent("Debug-iphoneos")
				.appendingPathComponent(name)
				.appendingPathComponent("Objects-normal")
				.appendingPathComponent("arm64")
		}

		guard FileManager.default.directoryExists(at: objectsPath) else {
			throw Error.projectHasNotBeenBuilt("Failed to find required build folders. It is required that the current version of the project has been built in debug mode targeting iOS")
		}

		return objectsPath
	}

	private func getSourceFiles() throws -> SourceFiles {
		let path = try getObjectsPath()
		return .init(swiftFiles: try getSwiftSourceFiles(in: path), objcFiles: try getObjcSourceFiles(in: path))
	}

	// TODO: found a SwiftFileList file - this might be easier to get swift files with?
	private func getSwiftSourceFiles(in path: URL) throws -> [URL] {
		// The compiler stores a mapping of Swift files to their depenencies & artifacts in an OutputFileMap.json file
		// This file uses the file path as the key to a JSON dict of information, we only care about the file paths (non-empty keys)
		try FileManager.default.getFiles(at: path, withSuffix: "-OutputFileMap.json", recursive: false)
			.map { try Data(contentsOf: $0) }
			.map { try JSONDecoder().decode(OutputFileMap.self, from: $0) }
			.flatMap { Array($0.keys) }
			.filter { !$0.isEmpty }
			.map { $0.fileURL }
	}

	private func getObjcSourceFiles(in path: URL) throws -> [URL] {
		// The compiler stores a depenencies map for ObjC in .d files
		// These are not to be confused with regular .d files that contain... other things
		// FORMAT:
		// dependencies: FILE \
		//       FILE \
		//       FILE
		let dependenciesToken = "dependencies: "
		let allowedExtensions = ["m", "mm", "c"] // TODO: does this need to include cxx, c++, user provided file names etc

		let paths = try FileManager.default.getFiles(at: path, withSuffix: ".d")
			.compactMap { try? String(contentsOf: $0) }
			.filter { $0.starts(with: dependenciesToken) }
			.flatMap { contents /*-> [String]*/ in
				// Strip file contents to just file paths
				return contents.dropFirst(dependenciesToken.count)
					.split(separator: "\n")
					.map { $0.last == "\\" ? $0.dropLast() : $0 }
					.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			}

		return paths.compactMap { filePath -> String? in
			guard let index = filePath.lastIndex(of: ".") else {
				return nil
			}

			let suffix = filePath.lowercased().suffix(from: filePath.index(after: index))

			return allowedExtensions.contains(String(suffix)) ? filePath : nil
		}
		.map { $0.fileURL }
	}
}
