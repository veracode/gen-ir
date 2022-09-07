//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 04/07/2022.
//

import Foundation

struct XcodeConfiguration: Configuration {
	let projectFilePath: URL
	let objcBridgingHeader: URL?
	let derivedDataPath: URL

	let projectName: String
	let targetName: String
	let configuration: String
	let sdkName: String
	let productModuleName: String
	let frameworkPaths: String?

	let scheme: String

	let iphoneOSDeploymentTarget: String

	var buildSettings: [String: String]

	let shouldSkipGenSil: Bool
	let output: URL

	init(from environment: EnvironmentMap) throws {
		buildSettings = environment

		projectFilePath   = try Self.extract(.projectFilePath, from: environment).fileURL
		projectName       = try Self.extract(.projectName, from: environment)
		targetName        = try Self.extract(.targetName, from: environment)
		configuration     = try Self.extract(.configuration, from: environment)
		sdkName           = try Self.extract(.sdkName, from: environment)
		productModuleName = try Self.extract(.productModuleName, from: environment)
		frameworkPaths    = try Self.extract(.frameworkPath, from: environment).trimmingCharacters(in: .whitespacesAndNewlines)
		iphoneOSDeploymentTarget = try Self.extract(.iphoneOSDeploymentTarget, from: environment)

		objcBridgingHeader = environment[XcodeBuildSettingsKeys.objcBridgingHeader.rawValue]?.fileURL

		let path = try Self.extract(.outputPath, from: environment)
		if #available(macOS 13.0, *) {
			output = URL(filePath: path)
		} else {
			output = URL(fileURLWithPath: path)
		}

		if let targetBuildDirectory = buildSettings[XcodeBuildSettingsKeys.targetBuildDirectory.rawValue] {
			derivedDataPath = targetBuildDirectory.fileURL.deletingLastPathComponent()
				.deletingLastPathComponent()
				.deletingLastPathComponent()
		} else {
			derivedDataPath = "\(NSHomeDirectory())/Library/Developer/Xcode/DerivedData/".fileURL
		}

		// special handling for skip cases as we want to default if it doesn't exist
		shouldSkipGenSil = environment["SHOULD_SKIP_GEN_SIL"] == "1" ? true : false

		if let scheme = buildSettings["SCHEME"] {
			self.scheme = scheme
		} else {
			throw ConfigurationError.configurationKeyNotFound("Scheme was not provided")
		}
	}
}
