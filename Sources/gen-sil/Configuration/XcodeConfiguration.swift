//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 04/07/2022.
//

import Foundation

enum XcodeConfigurationKeys: String {
	case projectName = "PROJECT_NAME"
	case targetName = "TARGET_NAME"
	case configuration = "CONFIGURATION"
	case sdkName = "SDK_NAME"
	case productModuleName = "PRODUCT_MODULE_NAME"
	case frameworkPath = "FRAMEWORK_SEARCH_PATHS"
	case shouldSkipGenSil = "SHOULD_SKIP_GEN_SIL"
	case outputPath = "GEN_SIL_OUTPUT_PATH"
}

struct XcodeConfiguration: Configuration {
	let projectName: String
	let targetName: String
	let configuration: String
	let sdkName: String
	let productModuleName: String
	let frameworkPath: String
	let shouldSkipGenSil: Bool
	let output: URL

	init(from environment: EnvironmentMap) throws {
		projectName       = try Self.extract(.projectName, from: environment)
		targetName        = try Self.extract(.targetName, from: environment)
		configuration     = try Self.extract(.configuration, from: environment)
		sdkName           = try Self.extract(.sdkName, from: environment)
		productModuleName = try Self.extract(.productModuleName, from: environment)
		frameworkPath     = try Self.extract(.frameworkPath, from: environment).trimmingCharacters(in: .whitespacesAndNewlines)

		let path = try Self.extract(.outputPath, from: environment)
		if #available(macOS 13.0, *) {
			output = URL(filePath: path)
		} else {
			output = URL(fileURLWithPath: path)
		}

		// special handling for skip cases as we want to default if it doesn't exist
		let skipKey = XcodeConfigurationKeys.shouldSkipGenSil.rawValue
		shouldSkipGenSil = environment[skipKey] == "1" ? true : false
	}
	
	private static func extract(_ key: XcodeConfigurationKeys, from environment: EnvironmentMap) throws -> String {
		if let value = environment[key.rawValue] {
			return value
		}
		
		throw ConfigurationError.configurationError(message: "\(key.rawValue) not found in configuration dictionary")
	}
}
