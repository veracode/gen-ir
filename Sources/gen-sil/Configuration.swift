//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 04/07/2022.
//

import Foundation

typealias Environment = [String: String]

fileprivate enum ConfigurationKeys: String {
	case projectName = "PROJECT_NAME"
	case targetName = "TARGET_NAME"
	case configuration = "CONFIGURATION"
	case sdkName = "SDK_NAME"
	case productModuleName = "PRODUCT_MODULE_NAME"
	case frameworkPath = "FRAMEWORK_SEARCH_PATHS"
	case shouldSkipGenSil = "SHOULD_SKIP_GEN_SIL"
}

struct Configuration {
	let projectName: String
	let targetName: String
	let configuration: String
	let sdkName: String
	let productModuleName: String
	let frameworkPath: String
	let shouldSkipGenSil: Bool
	
	var target: String?

	enum Error: Swift.Error {
		case configurationError(message: String)
	}
	
	init(from environment: Environment) throws {
		projectName       = try Self.extract(.projectName, from: environment)
		targetName        = try Self.extract(.targetName, from: environment)
		configuration     = try Self.extract(.configuration, from: environment)
		sdkName           = try Self.extract(.sdkName, from: environment)
		productModuleName = try Self.extract(.productModuleName, from: environment)
		frameworkPath     = try Self.extract(.frameworkPath, from: environment).trimmingCharacters(in: .whitespacesAndNewlines)
		shouldSkipGenSil  = try Self.extract(.shouldSkipGenSil, from: environment) == "1" ? true : false
	}
	
	private static func extract(_ key: ConfigurationKeys, from environment: Environment) throws -> String {
		if let value = environment[key.rawValue] {
			return value
		}
		
		throw Error.configurationError(message: "\(key.rawValue) not found in configuration dictionary")
	}
}
