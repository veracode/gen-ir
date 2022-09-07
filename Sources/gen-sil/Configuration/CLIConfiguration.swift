//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 27/07/2022.
//

import Foundation

public enum XcodeProjectPath {
	case project(URL)
	case workspace(URL)
}

// TODO: Ensure this doesn't loop if some idiot adds this command to a build phase....
public class CLIConfiguration: Configuration {
	let path: XcodeProjectPath
	let output: URL

	let projectFilePath: URL
	let objcBridgingHeader: URL?
	let frameworkPaths: String?
	let derivedDataPath: URL

	let projectName: String
	let sdkName: String

	let targetName: String
	let productModuleName: String
	let configuration: String
	let scheme: String

	let iphoneOSDeploymentTarget: String

	let buildSettings: [String: String]

	init(_ pathType: XcodeProjectPath, output: URL, buildSettings: [String: String], scheme: String) throws {
		// TODO: move command line configuration (i.e. build settings here!)
		path = pathType
		self.output = output
		self.buildSettings = buildSettings
		self.scheme = scheme

		switch path {
		case .project(let url), .workspace(let url):
			self.projectFilePath = url
			self.projectName = (url.lastPathComponent as NSString).deletingPathExtension
		}

		sdkName = try Self.extract(.sdkName, from: buildSettings)
		targetName = try Self.extract(.targetName, from: buildSettings)
		productModuleName = try Self.extract(.productModuleName, from: buildSettings)
		configuration = try Self.extract(.configuration, from: buildSettings)
		iphoneOSDeploymentTarget = try Self.extract(.iphoneOSDeploymentTarget, from: buildSettings)

		if let targetBuildDirectory = buildSettings[XcodeBuildSettingsKeys.targetBuildDirectory.rawValue] {
			derivedDataPath = targetBuildDirectory.fileURL.deletingLastPathComponent()
				.deletingLastPathComponent()
				.deletingLastPathComponent()
		} else {
			derivedDataPath = "\(NSHomeDirectory())/Library/Developer/Xcode/DerivedData/".fileURL
		}

		frameworkPaths = buildSettings[XcodeBuildSettingsKeys.frameworkPath.rawValue]

		if let headerName = buildSettings[XcodeBuildSettingsKeys.objcBridgingHeader.rawValue] {
			objcBridgingHeader = projectFilePath.deletingLastPathComponent().appendingPathComponent(headerName)
		} else {
			objcBridgingHeader = nil
		}
	}
}
