//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 27/07/2022.
//

import Foundation

protocol Configuration {
	/* Xcode specific configuration */
	// Paths
	var derivedDataPath: URL { get }
	var projectFilePath: URL { get }
	var objcBridgingHeader: URL? { get }
	var frameworkPaths: String? { get }

	var scheme: String { get }

	var projectName: String { get }
	var sdkName: String { get }
	var targetName: String { get }
	var productModuleName: String { get }
	var configuration: String { get }

	var iphoneOSDeploymentTarget: String { get }


	var buildSettings: [String: String] { get }

	// TODO: This
//	var buildSettings: [String: String] { get }

	// User options
	var output: URL { get }
}

extension Configuration {
	static func extract(_ key: XcodeBuildSettingsKeys, from dictionary: [String: String]) throws -> String {
		if let value = dictionary[key.rawValue] {
			return value
		}

		throw ConfigurationError.configurationKeyNotFound("\(key.rawValue) not found in configuration dictionary")
	}
}

enum ConfigurationError: Swift.Error {
	case configurationKeyNotFound(String)
	case configurationError(message: String)
	case wrongConfiguration(String)
}

enum XcodeBuildSettingsKeys: String {
	case projectFilePath = "PROJECT_FILE_PATH"
	case projectName = "PROJECT_NAME"
	case targetName = "TARGET_NAME"
	case configuration = "CONFIGURATION"
	case sdkName = "SDK_NAME"
	case productModuleName = "PRODUCT_MODULE_NAME"
	case frameworkPath = "FRAMEWORK_SEARCH_PATHS"
	case outputPath = "GEN_SIL_OUTPUT_PATH"
	case objcBridgingHeader = "SWIFT_OBJC_BRIDGING_HEADER"
	case targetBuildDirectory = "TARGET_BUILD_DIR"
	case iphoneOSDeploymentTarget = "IPHONEOS_DEPLOYMENT_TARGET"
}
