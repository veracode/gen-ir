//
//  PifCacheHandler.swift
//
//
//  Created by Kevin Rise on 24/11/2023.
//

// Handle parsing the files in the PIFCache directory

import Foundation

public struct PifCacheHandler {
	private var pifCacheLocation: URL
	private let jsonFileExtension = "-json"

	enum PifError: Error {
		case setupError(_ msg: String)
		case processingError(_ msg: String)
	}

	public init(pifCache: URL) {
		self.pifCacheLocation = pifCache
	}

	// parse the Target files in the PIFCache directory
	public func getTargets(targets: inout [String: GenTarget]) throws {
		logger.info("Parsing PIFCache Target files")

		// pass 1: get all the files
		let fmgr = FileManager.default
		let targetParser = PifTargetParser()
		let targetDir = pifCacheLocation.appendingPathComponent("target", isDirectory: true)

		do {
			let files = try fmgr.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: nil)

			logger.info("Pass 1: loading all target files")
			for file in files {
				logger.debug("Found file: \(file)")

				do {
					let pifTarget = try targetParser.process(file)
					logger.debug("PifTarget: \(pifTarget.name) [\(pifTarget.guid)]")

					var typeName: String
					if pifTarget.productTypeIdentifier != nil {
						typeName = pifTarget.productTypeIdentifier!
					} else {
						typeName = pifTarget.type
					}

					// skip Playground targets
					// (what we want for root targets become children of Playgrounds)
					if pifTarget.guid.hasPrefix("PLAYGROUND") {
						logger.debug("skipping Playground target \(pifTarget.name) [\(pifTarget.guid)]")
						continue
					}

					// skip macosx targets
					// (using [0] is fine, as we don't expect Debug for iPhone and Release for MacOSX)
					if pifTarget.buildConfigurations?[0].buildSettings.MACOSX_DEPLOYMENT_TARGET != nil {
						logger.debug("skipping macosx target \(pifTarget.name) [\(pifTarget.guid)]")
						continue
					}

					// frameworks that get pulled into this target
					var frameworkGuids: [String]?
					for phase in pifTarget.buildPhases ?? [] {
						if phase.type == "com.apple.buildphase.copy-files" {		// TODO: also need to verify this is going into the Frameworks folder?
							for buildFile in phase.buildFiles ?? [] {
								if let ref = buildFile.targetReference {
									if(frameworkGuids?.append(ref)) == nil {
										frameworkGuids = [ref]
									}
								}
							}
						}
					}

					// add this target to the list
					let gen = GenTarget(guid: pifTarget.guid, file: file, name: pifTarget.name,
									typeName: typeName, productReference: pifTarget.productReference,
									dependencyGuids: pifTarget.dependencies, frameworkGuids: frameworkGuids)
					targets[gen.guid] = gen
				} catch {
					throw PifError.processingError("Error parsing PifTarget [\(error)]")
				}
			}

			logger.info("Pass 2: resolving dependencies")
			for tgt in targets {
				logger.debug("tgt = \(tgt.value.guid)")
				for depGuid in (tgt.value.dependencyGuids ?? []) {
					logger.debug("depGuid = \(depGuid)")

					// target might not exist, like an iOS app hard-wired to use swiftlint (a macosx tool)
					if targets[depGuid] == nil {
						continue
					}

					if(tgt.value.dependencyTargets?.insert(targets[depGuid]!)) == nil {
						logger.debug("depGuid = \(depGuid)")
						tgt.value.dependencyTargets = [targets[depGuid]!]
					}

					targets[depGuid]?.isDependency = true
				}
			}

			logger.info("Pass 3: resolving frameworks")
			for tgt in targets {
				for frGuid in (tgt.value.frameworkGuids ?? []) {
					// swiftlint:disable:next for_where
					if(tgt.value.frameworkTargets?.insert(targets[frGuid]!)) == nil {
						tgt.value.frameworkTargets = [targets[frGuid]!]
					}
				}
			}
		} catch {
			throw PifError.processingError("Error finding/resolving Target files [\(error)]")
		}
	}

	// parse the Project files in the PIFCache directory
	public func getProjects(targets: [String: GenTarget], projects: inout [GenProject]) throws {
		logger.info("Parsing PIFCache Project files")

		// pass 1: get all the files
		let fmgr = FileManager.default
		let projectParser = PifProjectParser()
		let projectDir = pifCacheLocation.appendingPathComponent("project", isDirectory: true)

		do {
			let files = try fmgr.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil)

			for file in files {
				logger.info("Found file: \(file)")

				do {
					let pifProject = try projectParser.process(file)
					logger.debug("PifProject: \(pifProject.name) [\(pifProject.guid)]")

					// create the project data struct
					let prj = GenProject(guid: pifProject.guid, filename: file, name: pifProject.name)

					// add targets to this project
					for tgt in pifProject.targets {
						var found = false
						for search in targets {
							// swiftlint:disable:next for_where
							if tgt + jsonFileExtension == search.value.file.lastPathComponent {
								prj.addTarget(target: targets[search.value.guid]!)
								found = true
								break // allow multiples ??
							}
						}

						if !found {
							logger.info("Unable to find target \(tgt) in target list (ignored Playground or MacOSX target?)")
						}
					}

					// add this project to the list
					projects.append(prj)
				} catch {
					throw PifError.processingError("Error parsing PifProject [\(error)]")
				}
			}
		} catch {
			throw PifError.processingError("Error finding Project files [\(error)]")
		}

		// check for a workspace file
		// do I need to?   The workspace is just a list of projects

	}
}

/*
 * PIFCache Target files
 */

// swiftlint:disable identifier_name
private struct BuildSetting: Codable {
	let MACOSX_DEPLOYMENT_TARGET: String?

	public init(MACOSX_DEPLOYMENT_TARGET: String) {
		self.MACOSX_DEPLOYMENT_TARGET = MACOSX_DEPLOYMENT_TARGET
	}
}
// swiftlint:enable identifier_name

private struct BuildConfiguration: Codable {
	let buildSettings: BuildSetting
	let name: String
	let guid: String

	public init(name: String, guid: String, buildSettings: BuildSetting) {
		self.name = name
		self.guid = guid
		self.buildSettings = buildSettings
	}
}

private struct BuildFile: Codable {
	let guid: String
	let targetReference: String?

	public init(guid: String, targetReference: String?) {
		self.guid = guid
		self.targetReference = targetReference
	}
}

private struct BuildPhase: Codable {
	let buildFiles: [BuildFile]?
	let guid: String
	let type: String

	public init(buildFiles: [BuildFile]?, guid: String, type: String) {
		self.buildFiles = buildFiles
		self.guid = guid
		self.type = type
	}
}

private struct Dependencies: Codable {
	let guid: String

	public init(guid: String) {
		self.guid = guid
	}
}

// TODO: same as one in GenTarget - clean-up/combine
public struct ProductReference: Codable {
	let guid: String
	let name: String
	let type: String

	public init(guid: String, name: String, type: String) {
		self.guid = guid
		self.name = name
		self.type = type
	}
}

// Raw target direct from the JSON file(s)
// TODO: do I really need this raw to normal conversion?
private struct PifTargetRaw: Codable {
	let guid: String
	let name: String
	let type: String
	let productReference: ProductReference?
	let productTypeIdentifier: String?
	let dependencies: [Dependencies]?
	let buildPhases: [BuildPhase]?
	let buildConfigurations: [BuildConfiguration]?

	public init(
		guid: String,
		name: String,
		type: String,
		productReference: ProductReference?,
		productTypeIdentifier: String?,
		dependencies: [Dependencies]?,
		buildPhases: [BuildPhase]?,
		buildConfigurations: [BuildConfiguration]?
	) {
		self.guid = guid
		self.name = name
		self.type = type
		self.productReference = productReference

		// typeIdentifier is only valid when type=="standard"
		if type == "standard" {
			self.productTypeIdentifier = productTypeIdentifier
		} else {
			self.productTypeIdentifier = nil
		}

		self.dependencies = dependencies
		self.buildPhases = buildPhases
		self.buildConfigurations = buildConfigurations
	}
}

// converted various RawTargets into a common format
private struct PifTarget {
	let guid: String
	let name: String
	let type: String
	let productTypeIdentifier: String?
	let productReference: ProductReference?
	var dependencies: [String]?
	let buildPhases: [BuildPhase]?
	let buildConfigurations: [BuildConfiguration]?

	public init(rawTarget: PifTargetRaw) {
		self.guid = rawTarget.guid
		self.name = rawTarget.name
		self.type = rawTarget.type
		self.productTypeIdentifier = rawTarget.productTypeIdentifier
		self.productReference = rawTarget.productReference
		self.buildPhases = rawTarget.buildPhases
		self.buildConfigurations = rawTarget.buildConfigurations

		if rawTarget.dependencies != nil {
			for dep in rawTarget.dependencies! {
				// swiftlint:disable:next for_where
				if(self.dependencies?.append(dep.guid)) == nil {
					self.dependencies = [dep.guid]
				}
			}
		}
	}
}

private class PifTargetParser {
	private let decoder: JSONDecoder

	public init() {
		decoder = JSONDecoder()
	}

	public func process(_ path: String) throws -> PifTarget {
		return try process(URL(fileURLWithPath: path))
	}

	public func process(_ url: URL) throws -> PifTarget {
		let data = try Data(contentsOf: url)
		let rawTarget = try decoder.decode(PifTargetRaw.self, from: data)
		let tgt = PifTarget(rawTarget: rawTarget)
		return tgt
	}
}

/*
 * PIFCache Project files
 */
private struct GroupTree: Codable {
	let name: String

	public init(name: String) {
		self.name = name
	}
}

// Raw project direct from the JSON file(s)
private struct PifProjectRaw: Codable {
	let guid: String
	let groupTree: GroupTree
	let projectName: String?
	let targets: [String]		// Optional?

	public init(
		guid: String,
		groupTree: GroupTree,
		projectName: String?,
		targets: [String]
	) {
		self.guid = guid
		self.groupTree = groupTree
		self.projectName = projectName
		self.targets = targets
	}
}

// converted various RawProjects into a common format
private struct PifProject {
	let guid: String
	let name: String
	let targets: [String]   	// Optional?

	public init(rawProject: PifProjectRaw) {
		self.guid = rawProject.guid

		if rawProject.projectName != nil {
			self.name = rawProject.projectName!
		} else {
			self.name = rawProject.groupTree.name
		}

		self.targets = rawProject.targets
	}
}

private class PifProjectParser {
	private let decoder: JSONDecoder

	public init() {
		decoder = JSONDecoder()
	}

	public func process(_ path: String) throws -> PifProject {
		return try process(URL(fileURLWithPath: path))
	}

	public func process(_ url: URL) throws -> PifProject {
		let data = try Data(contentsOf: url)
		let rawProject = try decoder.decode(PifProjectRaw.self, from: data)
		let prj = PifProject(rawProject: rawProject)
		return prj
	}
// swiftlint:disable:next file_length
}
