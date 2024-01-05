//
//  PifCacheHandler.swift
//
//
//  Created by Kevin Rise on 24/11/2023.
//

// Handle parsing the files in the PIFCache directory

import Foundation

public struct PifCacheHandler {
	private var manifestLocation: ManifestLocation?
	private let jsonFileExtension = "-json"

	enum PifError: Error {
		case setupError(_ msg: String)
		case processingError(_ msg: String)
	}

	public init(project: URL) throws {
		// find the PIFCache folder
		let manifestFinder = ManifestFinder()

		do {
			manifestLocation = try manifestFinder.findLatestManifest(options: .build(project: project))
			logger.info("Found PIFCache \(manifestLocation!.pifCache!)")
		} catch let error as ManifestFinderError {
			throw PifError.setupError("Unable to find PIFCache - \(error.errorDescription!), \(error.recoverySuggestion!)")
		}
	}

	// parse the Target files in the PIFCache directory
	public func getTargets(targets: inout [String: GenTarget]) throws {
		logger.info("Parsing PIFCache Target files")

		guard self.manifestLocation != nil else {
			throw PifError.processingError("PifCache, manifest location unknown")
		}

		guard self.manifestLocation!.pifCache != nil else {
			throw PifError.processingError("PifCache, PIFCache lcation unknown")
		}

		// pass 1: get all the files
		let fm = FileManager.default
		let targetParser = PifTargetParser()
		let targetDir = manifestLocation!.pifCache!.appendingPathComponent("target", isDirectory: true)

		do {
			let files = try fm.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: nil)

			logger.info("Pass 1: loading all target files")
			for file in files {
				logger.debug("Found file: \(file)")

				do {
					let pifTarget = try targetParser.process(file)
					logger.debug("PifTarget: \(pifTarget)")

					var typeName: String
					if pifTarget.productTypeIdentifier != nil {
						typeName = pifTarget.productTypeIdentifier!
					} else {
						typeName = pifTarget.type
					}

					// skip Playground targets
					// (what we want for root targets become children of Playgrounds)
					if pifTarget.guid.hasPrefix("PLAYGROUND") {
						continue
					}

					// add this target to the list
					let g = GenTarget(guid: pifTarget.guid, file: file, name: pifTarget.name, 
									typeName: typeName, productReference: pifTarget.productReference, dependencyNames: pifTarget.dependencies)
					//targets[file.lastPathComponent] = g
					targets[g.guid] = g
				} catch {
					throw PifError.processingError("Error parsing PifTarget [\(error)]")
				}
			}

			logger.info("Pass 2: resolving dependencies")
			for t in targets {
				for depName in (t.value.dependencyNames ?? []) {
					// for search in targets {
					// 	if depName == search.value.guid {
					// 		if(t.value.dependencyTargets?.append(search.value)) == nil {
					// 			t.value.dependencyTargets = [search.value]
					// 		}

					// 		// flag this target as a dependency (aka not a root target)
					// 		search.value.isDependency = true
					// 	}
					// }

					if(t.value.dependencyTargets?.insert(targets[depName]!)) == nil {
						t.value.dependencyTargets = [targets[depName]!]
					}

					targets[depName]?.isDependency = true
				}
			}
		} catch {
			throw PifError.processingError("Error finding Target files [\(error)]")
		}
	}

	// parse the Project files in the PIFCache directory
	public func getProjects(targets: [String: GenTarget], projects: inout [GenProject]) throws {
		logger.info("Parsing PIFCache Project files")

		guard self.manifestLocation != nil else {
			throw PifError.processingError("PifCache, manifest location unknown")
		}

		guard self.manifestLocation!.pifCache != nil else {
			throw PifError.processingError("PifCache, PIFCache lcation unknown")
		}

		// pass 1: get all the files
		let fm = FileManager.default
		let projectParser = PifProjectParser()
		let projectDir = manifestLocation!.pifCache!.appendingPathComponent("project", isDirectory: true)

		do {
			let files = try fm.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil)

			for file in files {
				logger.info("Found file: \(file)")

				do {
					let pifProject = try projectParser.process(file)
					logger.debug("PifProject: \(pifProject)")

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
							logger.info("Unable to find target \(t) in target list (ignored Playground target?)")
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

	public init(
		guid: String,
		name: String,
		type: String,
		productReference: ProductReference?,
		productTypeIdentifier: String? ,
		dependencies: [Dependencies]?
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

	public init(rawTarget: PifTargetRaw) {
		self.guid = rawTarget.guid
		self.name = rawTarget.name
		self.type = rawTarget.type
		self.productTypeIdentifier = rawTarget.productTypeIdentifier
		self.productReference = rawTarget.productReference

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