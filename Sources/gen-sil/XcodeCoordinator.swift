//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 08/07/2022.
//

import Foundation

struct XcodeCoordinator {
	private static let xcrun = "/usr/bin/xcrun"
	
	enum EmitType: String {
		case ir = "-emit-ir"
		case sil = "-emit-sil"
	}

	enum Error: Swift.Error {
		case archiveFailed(String)
		case noTarget(String)
		case noSourceFiles(String)	
	}
	
	// MARK: - Public
	func archive(with config: Configuration, environment: Environment) throws -> String? {
		// clean the project so Xcode doesn't skip invocations of swiftc
		_ = try Process.runShell(
			Self.xcrun,
			arguments: [
				"xcodebuild", "clean"
			],
			environment: environment
		)
		
		// build the project
		return try Process.runShell(
			Self.xcrun,
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
	
	func parseTarget(from output: String) throws -> String? {
		let swiftcRegex = ".*/swiftc.*[\\s]+-target[\\s]+([^\\s]*).*"
		if let targetMatch = try Self.match(regex: swiftcRegex, in: output).first {
			return (output as NSString).substring(with: targetMatch.range(at: 1))
		}
		
		return nil
	}
	
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
	
	func emit(_ emit: EmitType, for path: String, target: String, config: Configuration) throws -> String? {
		var arguments = getArguments(for: path, target: target, with: config)
		arguments.append(emit.rawValue)
		
		return try Process.runShell(Self.xcrun, arguments: arguments)
	}
	
	
	// MARK: - Private
	private func getArguments(for path: String, target: String, with config: Configuration) -> [String] {
		let filename = ((path as NSString).lastPathComponent as String)
		
		var arguments = [
			"-sdk",
			config.sdkName,
			"swiftc",
			"-g",
			"-o", "/Users/thedderwick/Desktop/sil/\(filename).ll",
			"-F", config.frameworkPath,
			"-target", target, // TODO: is this the same as config.targetName?
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
	
	private static func match(regex: String, in text: String) throws -> [NSTextCheckingResult] {
		let regex = try NSRegularExpression(pattern: regex)
		return regex.matches(in: text, range: NSRange(location: 0, length: text.count))
	}
}
