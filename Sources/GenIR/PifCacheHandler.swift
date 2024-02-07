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
		let fm = FileManager.default
		let targetParser = PifTargetParser()
		let targetDir = pifCacheLocation.appendingPathComponent("target", isDirectory: true)

		do {
			let files = try fm.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: nil)

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
					let g = GenTarget(guid: pifTarget.guid, file: file, name: pifTarget.name, 
									typeName: typeName, productReference: pifTarget.productReference, 
									dependencyGuids: pifTarget.dependencies, frameworkGuids: frameworkGuids)
					targets[g.guid] = g
				} catch {
					throw PifError.processingError("Error parsing PifTarget [\(error)]")
				}
			}

			logger.info("Pass 2: resolving dependencies")
			for t in targets {
				logger.debug("t = \(t.value.guid)")
				for depGuid in (t.value.dependencyGuids ?? []) {
					logger.debug("depGuid = \(depGuid)")

					// target might not exist, like an iOS app hard-wired to use swiftlint (a macosx tool)
					if targets[depGuid] == nil {
						continue
					}
					
					if(t.value.dependencyTargets?.insert(targets[depGuid]!)) == nil {
						logger.debug("depGuid = \(depGuid)")
						t.value.dependencyTargets = [targets[depGuid]!]
					}

					targets[depGuid]?.isDependency = true
				}
			}

			logger.info("Pass 3: resolving frameworks")
			for t in targets {
				for frGuid in (t.value.frameworkGuids ?? []) {
					if(t.value.frameworkTargets?.insert(targets[frGuid]!)) == nil {
						t.value.frameworkTargets = [targets[frGuid]!]
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
		let fm = FileManager.default
		let projectParser = PifProjectParser()
		let projectDir = pifCacheLocation.appendingPathComponent("project", isDirectory: true)

		do {
			let files = try fm.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil)

			for file in files {
				logger.info("Found file: \(file)")

				do {
					let pifProject = try projectParser.process(file)
					logger.debug("PifProject: \(pifProject.name) [\(pifProject.guid)]")

					// create the project data struct
					let p = GenProject(guid: pifProject.guid, filename: file, name: pifProject.name)

					// add targets to this project
					for t in pifProject.targets {
						var found = false
						for search in targets {
							if t + jsonFileExtension == search.value.file.lastPathComponent {
								p.addTarget(target: targets[search.value.guid]!)
								found = true
								break // allow multiples ??
							}
						}

						if !found {
							logger.info("Unable to find target \(t) in target list (ignored Playground or MacOSX target?)")
						}
					}

					// add this project to the list
					projects.append(p)
				} catch {
					throw PifError.processingError("Error parsing PifProject [\(error)]")
				}
			}
		} catch {
			throw PifError.processingError("Error finding Project files [\(error)]")
		}


		// ?? pass 2: work out any inter-project dependencies


		// check for a workspace file
		// do I need to?   The workspace is just a list of projects

	}

}

/*
 * PIFCache Target files
 */

private struct buildSetting: Codable {
	//let SDKROOT: String?
	let MACOSX_DEPLOYMENT_TARGET: String?

	public init(/*SDKROOT: String,*/ MACOSX_DEPLOYMENT_TARGET: String) {
		//self.SDKROOT = SDKROOT
		self.MACOSX_DEPLOYMENT_TARGET = MACOSX_DEPLOYMENT_TARGET
	}
}

private struct buildConfiguration: Codable {
	let buildSettings: buildSetting
	let name: String
	let guid: String

	public init(name: String, guid: String, buildSettings: buildSetting) {
		self.name = name
		self.guid = guid
		self.buildSettings = buildSettings
	}
}

private struct buildFile: Codable {
	let guid: String
	let targetReference: String?

	public init(guid: String, targetReference: String?) {
		self.guid = guid
		self.targetReference = targetReference
	}
}

private struct buildPhase: Codable {
	let buildFiles: [buildFile]?
	let guid: String
	let type: String

	public init(buildFiles: [buildFile]?, guid: String, type: String) {
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
	let buildPhases: [buildPhase]?
	let buildConfigurations: [buildConfiguration]?

	public init(
		guid: String,
		name: String,
		type: String,
		productReference: ProductReference?,
		productTypeIdentifier: String? ,
		dependencies: [Dependencies]?,
		buildPhases: [buildPhase]?,
		buildConfigurations: [buildConfiguration]?
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
	let buildPhases: [buildPhase]?
	let buildConfigurations: [buildConfiguration]?

	public init(rawTarget: PifTargetRaw) {
		self.guid = rawTarget.guid
		self.name = rawTarget.name
		self.type = rawTarget.type
		self.productTypeIdentifier = rawTarget.productTypeIdentifier
		self.productReference = rawTarget.productReference
		self.buildPhases = rawTarget.buildPhases
		self.buildConfigurations = rawTarget.buildConfigurations

		if rawTarget.dependencies != nil {
			for d in rawTarget.dependencies! {
				if(self.dependencies?.append(d.guid)) == nil {
					self.dependencies = [d.guid]
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
		let t = PifTarget(rawTarget: rawTarget)
		return t
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
		projectName: String? ,
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
		let p = PifProject(rawProject: rawProject)
		return p
	}
}