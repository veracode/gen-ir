//
//  File.swift
//
//
//  Created by Thomas Hedderwick on 27/07/2022.
//

import Foundation

/* TODO:
 * OutputFileMap.json can be parsed for files?
 * ./Build/Intermediates.noindex/LocationTest.build/Debug-iphoneos/LocationTest.build/Objects-normal/arm64/LocationTest-OutputFileMap.json
 */
class CLIRunner: Runner {
	private let config: CLIConfiguration
	private var state: State = .initialized

	enum Error: Swift.Error {
		case failedToCreate(URL)
		// TODO: pass stdout/stderr to this?
		case shellCommandFailed
	}

	enum State: String {
		case initialized
		case fetchingRequiredInformation = "Fetch Required Information"
	}

	init(configuration: CLIConfiguration) throws {
		config = configuration
	}

	public func run() throws {
		try createDirectory(config.output)

		setState(.fetchingRequiredInformation)
		let derivedData = try getDerivedData()
	}

	private func setState(_ state: State) {
		self.state = state
		print("[+] \(state.rawValue)")
	}

	private func createDirectory(_ path: URL) throws {
		try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
	}

	private func getDerivedData() throws -> URL {
		// Derived Data can be set at a per-project level, so we need to ask xcodebuild for this information
		var arguments = [
			"-showBuildSettings"
		]

		switch config.path {
		case .project(let url):
			arguments.append("-project")
			arguments.append(url.absoluteString)
		case .workspace(let url):
			arguments.append("-workspace")
			arguments.append(url.absoluteString)
		}

		guard let stdout = try Process.runShell("xcodebuild", arguments: arguments) else {
			throw Error.shellCommandFailed
		}

		print(stdout)

		return URL(string: "")!
	}
}
