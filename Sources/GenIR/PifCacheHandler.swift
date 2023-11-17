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

	// TODO: is project needed?
	public init(project: URL, scheme: String) {
		// find the PIFCache folder
		let manifestFinder = ManifestFinder()

		do {
			manifestLocation = try manifestFinder.findLatestManifest(options: .build(project: project, scheme: scheme))
			logger.info("Found PIFCache \(manifestLocation!.pifCache!)")
		} catch {
			logger.error("Error looking for PIFCache")
		}
	}

	// parse the Target files in the PIFCache directory
	public func getTargets(targets: inout [String: GenTarget]) {

		logger.info("Parsing PIFCache Target files")

		guard self.manifestLocation != nil else {
			logger.error("PifCache, manifest location unknown")
			return
		}

		guard self.manifestLocation!.pifCache != nil else {
			logger.error("PifCache, PIFCache lcation unknown")
			return
		}

		// pass 1: get all the files
		let fm = FileManager.default
		let targetParser = PifTargetParser()
		let targetDir = manifestLocation!.pifCache!.appendingPathComponent("target", isDirectory: true)

		do {
			let files = try fm.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: nil)

			for file in files {
				logger.debug("Found file: \(file)")

				do {
					let pifTarget = try targetParser.process(file)
					logger.debug("PifTarget: \(pifTarget)")

					// add this target to the list
					if pifTarget.productTypeIdentifier != nil {
						let g = GenTarget(guid: pifTarget.guid, file: file, name: pifTarget.name, typeName: pifTarget.productTypeIdentifier!)
						//targets.append(g)
						targets[file.lastPathComponent] = g
					} else {
						logger.debug("non-standard file")
						let g = GenTarget(guid: pifTarget.guid, file: file, name: pifTarget.name, typeName: pifTarget.type)
						//targets.append(g)
						targets[file.lastPathComponent] = g
					}
				} catch {
					logger.error("Error parsing PifTarget")
				}
			}
		} catch {
				logger.error("Error finding Target files")
		}

		// pass 2: work out any inter-target dependencies



	}

	// parse the Project files in the PIFCache directory
	public func getProjects(targets: [String: GenTarget], projects: inout [GenProject]) {

		logger.info("Parsing PIFCache Project files")

		guard self.manifestLocation != nil else {
			logger.error("PifCache, manifest location unknown")
			return
		}

		guard self.manifestLocation!.pifCache != nil else {
			logger.error("PifCache, PIFCache lcation unknown")
			return
		}

		// pass 1: get all the files
		let fm = FileManager.default
		let projectParser = PifProjectParser()
		let projectDir = manifestLocation!.pifCache!.appendingPathComponent("project", isDirectory: true)

		do {
			let files = try fm.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil)

			for file in files {
				logger.debug("Found file: \(file)")

				do {
					let pifProject = try projectParser.process(file)
					logger.debug("PifProject: \(pifProject)")

					// create the project data struct
					let p = GenProject(guid: pifProject.guid, filename: file, name: pifProject.groupTree.name)

					// add targets to this project
					for t in pifProject.targets {
						// if let tt = targets[t + "-json"] {
						// 	print("value for \(t) is \(tt)")
						// } else {
						// 	print("Key \(t) does not exist")
						// }



						if let tt = targets[t + "-json"] { 
							p.addTarget(target: tt)
						} else {
							logger.info("Unable to find target \(t) in target list")
						}
						//p.addTarget(target: targets[t])
					}

					// add this project to the list
					projects.append(p)
				} catch {
					logger.error("Error parsing PifProject")
				}
			}
		} catch {
				logger.error("Error finding Project files")
		}


		// ?? pass 2: work out any inter-project dependencies


		// check for a workspace file
		// do I need to?   The workspace is just a list of projects

	}

}

/*
 * PIFCache Target files
 */
private struct PifTarget: Codable {
	let guid: String
	let name: String
	let type: String
	let productTypeIdentifier: String?
	// ?? also need productReference.name, for cases where the ProductName != target name (xcconfig renaming)
	//		or for outputPostProcessing?

	public init(
		guid: String,
		name: String,
		type: String,
		productTypeIdentifier: String?
	) {
		self.guid = guid
		self.name = name
		self.type = type

		// typeIdentifier is only valid when type="standard"
		self.productTypeIdentifier = productTypeIdentifier
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
		return try decoder.decode(PifTarget.self, from: data)
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

private struct PifProject: Codable {
	let guid: String
	let groupTree: GroupTree
	let targets: [String]		// Optional?

	public init(
		guid: String,
		groupTree: GroupTree,
		targets: [String]
	) {
		self.guid = guid
		self.groupTree = groupTree
		self.targets = targets
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
		return try decoder.decode(PifProject.self, from: data)
	}
}