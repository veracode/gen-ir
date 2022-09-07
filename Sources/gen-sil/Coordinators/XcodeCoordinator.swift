//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 08/07/2022.
//

import Foundation

typealias EnvironmentMap = [String: String]

struct XcodeCoordinator {
	private static let xcrun = "/usr/bin/xcrun"

	/// Type of artifact to emit, and the command line option to swiftc that is used to generate it
	enum EmitType: String {
		case ir = "-emit-ir"
		case sil = "-emit-sil"
	}

	enum Error: Swift.Error {
		case archiveFailed(String)
		case noTarget(String)
		case noSourceFiles(String)
		case xcodeBuildFailed(String)
		case clangFailed(String)
	}
	
	// MARK: - Public

	/// Builds a Debug version of the project via `xcodebuild build`
	/// - Parameters:
	///   - config: configuration of the project
	///   - environment: the environment variables to expose to the underlying process
	/// - Returns: result of the build command
	func build(with config: Configuration, environment: EnvironmentMap) throws -> Process.ReturnValue {
		try Process.runShell(
			Self.xcrun,
			arguments: [
				"xcodebuild",
				"build",
				"-configuration", "Debug",
				"-project", config.projectFilePath.filePath,
				"-derivedDataPath", config.derivedDataPath.filePath,
				"-scheme", config.scheme,

			],
			environment: environment
		)
	}

	/// Archives a build of the project via `xcodebuild archive`
	/// - Parameters:
	///   - config: configuration of the project
	///   - environment: the environment variables to expose to the underlying process
	/// - Returns: result of the archive command
	func archive(with config: Configuration, environment: EnvironmentMap) throws -> Process.ReturnValue {
		// clean the project so Xcode doesn't skip invocations of swiftc
		try clean(with: config)
		
		// archive the project
		return try Process.runShell(
			Self.xcrun,
			arguments: [
				"xcodebuild",
				"archive",
				"-project", config.projectFilePath.filePath,
				"-target", config.targetName,
				"-configuration", "Debug",
				"-sdk", config.sdkName,
			],
			environment: environment
		)
	}

	/// Clean the project via `xcodebuild clean`
	/// - Parameter config: configutation of project
	func clean(with config: Configuration) throws {
		_ = try Process.runShell(
			Self.xcrun,
			arguments: [
				"xcodebuild", "clean", "-project", config.projectFilePath.filePath
			]
		)
	}

	// TODO: migrate this to configuration and parse build folder?
	func parseTarget(from output: String) throws -> String? {
		let swiftcRegex = ".*/swiftc.*[\\s]+-target[\\s]+([^\\s]*).*"
		if let targetMatch = try Self.match(regex: swiftcRegex, in: output).first {
			let res = (output as NSString).substring(with: targetMatch.range(at: 1))
			print("RESULT: \(res)")
			return res
		}
		
		return nil
	}

	// TODO: migrate these functions to parsing build folder? Will stop the need for the clean step
	func parseSourceFiles(from output: String) throws -> Set<String>? {
		let sourceRegex = "(/([^ ]|(?<=\\\\) )*\\.swift(?<!\\\\))"
		let sourceMatches = try Self.match(regex: sourceRegex, in: output)
		
		return Set(sourceMatches.map {
			(output as NSString).substring(with: $0.range(at: 1)).unescaped()
		}.filter {
			// TODO: lol no this is terrible
			!$0.contains("/build/")
		})
	}

	/// Asks the compiler to emit an artifact
	/// - Parameters:
	///   - emit: the type of artifact to emit
	///   - files: the files to emit artifacts for
	///   - config: configuration of the project
	/// - Returns: the result of the compiler command
//	func emit(_ emit: EmitType, forSourceFiles files: SourceFiles, config: Configuration) throws -> Process.ReturnValue {
//		let swift = files.swiftFiles
//		let objc = files.objcFiles
//
//		if objc.count > 0 {
//			let res = try self.emit(forObjCFiles: objc, config: config)
//			if res.didError {
//				print("TODO: OBJC ERROR: \(res.stdout ?? "No stdout ")\n\n\(res.stderr ?? "No stderr")")
//			}
//		}
//
//		return try self.emit(emit, forSwiftFiles: swift, config: config)
//	}

	public func emit(forSwiftFiles files: [URL], type: EmitType, config: Configuration) throws -> Process.ReturnValue {
//	private func emit(_ emit: EmitType, forSwiftFiles files: [URL], config: Configuration) throws -> Process.ReturnValue {
		var arguments = [
			"-sdk",
			config.sdkName,
			"swiftc",
			"-g",
			"-target", "arm64-apple-ios\(config.iphoneOSDeploymentTarget)",
			"-module-name", config.productModuleName,
		]

		if let bridgingHeader = config.objcBridgingHeader {
			arguments.append("-import-objc-header")
			arguments.append(bridgingHeader.filePath)
		}

		if let frameworkSearchPath = config.frameworkPaths {
			arguments.append("-F")
			arguments.append(frameworkSearchPath)
		}

		// HACK: see https://github.com/apple/swift/issues/55127
		// TODO: improve this check by looking for @main or other attributes
		arguments.append("-parse-as-library")
		arguments.append(type.rawValue)
		arguments.append(contentsOf: files.map { $0.filePath })

		return try Process.runShell(Self.xcrun, arguments: arguments)
	}

	public func emit(forObjCFiles files: [URL], config: Configuration) throws -> [URL] {
		var arguments = [
			"-sdk",
			config.sdkName,
			"clang",
			"-g",
			"-S",
			"-target", "arm64-apple-ios\(config.iphoneOSDeploymentTarget)",
			"-emit-llvm"
//			"-module-name", config.productModuleName,
		]

//		if let bridgingHeader = config.objcBridgingHeader {
//			arguments.append("-import-objc-header")
//			arguments.append(bridgingHeader.filePath)
//		}

		if let frameworkSearchPath = config.frameworkPaths {
			// TODO: is it just easier to parse the build log for compiler commands and then 
			// TODO: Frameworks need to be seperated out like so "-F framework -F framework2 -F framwork3"
			arguments.append("-F")
			arguments.append(frameworkSearchPath)
		}

		arguments.append(contentsOf: files.map { $0.filePath })

		// Clang outputs all the IR files to $filename.ll in the current working directory, so set it to some temp directory
		let temporaryDirectory = NSTemporaryDirectory().fileURL.appendingPathComponent("gen-sil-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

		let result = try Process.runShell(Self.xcrun, arguments: arguments, runInDirectory: temporaryDirectory)
		guard !result.didError else {
			print("emitting objc IR failed - stdout: \(result.stdout ?? "No stdout")\n\nstderr: \(result.stderr ?? "No stderr")")
			throw Error.clangFailed("TODO: error handling") // TODO: error handling
		}

		return try FileManager.default.getFiles(at: temporaryDirectory, withSuffix: ".ll")
	}

	public func getBuildSettings(for path: XcodeProjectPath, scheme: String) throws -> [String: String] {
		// Derived Data can be set at a per-project level, so we need to ask xcodebuild for this information
		var arguments = ["xcodebuild", "-showBuildSettings"]

		switch path {
		case .project(let url):
			arguments.append("-project")
			arguments.append(url.path)
		case .workspace(let url):
			arguments.append("-workspace")
			arguments.append(url.path)
		}

		arguments.append("-scheme")
		arguments.append(scheme)

		let processReturn = try Process.runShell(Self.xcrun, arguments: arguments)

		guard !processReturn.didError, let stdout = processReturn.stdout else {
			if let stderr = processReturn.stderr {
				throw Error.xcodeBuildFailed(stderr)
			} else {
				throw Error.xcodeBuildFailed("Unknown xcodebuild failure for command: xcodebuild \(arguments.joined())")
			}
		}

		return stdout.split(separator: "\n")
			.filter { $0.contains(" = ") }
			.map { $0.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
			.compactMap { parts in
				if let first = parts.first, let last = parts.last {
					return (String(first), String(last))
				}

				return nil
			}
			.reduce(into: [:]) { $0[$1.0] = $1.1 }
	}

	
	// MARK: - Private
	private static func match(regex: String, in text: String) throws -> [NSTextCheckingResult] {
		let regex = try NSRegularExpression(pattern: regex)
		return regex.matches(in: text, range: NSRange(location: 0, length: text.count))
	}
}
