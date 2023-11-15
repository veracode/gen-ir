//
//  PifCacheHandler.swift
//
//
//  Created by Kevin Rise on 24/11/2023.
//

// Handle parsing the files in the PIFCache directory

import Foundation
//import struct PBXProjParser.BuildTarget

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

	public func getTargets(targets: inout [GenTarget]) {

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
		do {
			let files = try fm.contentsOfDirectory(at: manifestLocation!.pifCache!, includingPropertiesForKeys: nil)

			for file in files {
				logger.debug("Found file: \(file)")

				do {
					let pifTarget = try targetParser.process(file)
					logger.debug("PifTarget: \(pifTarget)")

					// add this target to the list
					if pifTarget.productTypeIdentifier != nil {
						let g = GenTarget(guid: pifTarget.guid, filename: file, name: pifTarget.name, typeName: pifTarget.productTypeIdentifier!)
						targets.append(g)
					} else {
						logger.debug("non-standard file")
						let g = GenTarget(guid: pifTarget.guid, filename: file, name: pifTarget.name, typeName: pifTarget.type)
						targets.append(g)
					}

				} catch {
					logger.error("Error parsing PifTarget")
				}
			}
		} catch {
				logger.error("Error finding Target files")
		}

		// pass 2: work out the dependencies



	}

	public func getProjects(targets: [GenTarget], projects: inout [GenProject]) {

		
		// ?? other target files as parents ??  second pass to handle this?



		// parse the project files, basically parents of the projects




		// check for a workspace file
		// do I need to?   The workspace is just a list of projects, which we'll get in the next step

	}

}

private struct PifTarget: Codable {
	let guid: String
	let name: String
	let type: String
	let productTypeIdentifier: String?

	public init(
		guid: String,
		name: String,
		type: String,
		productTypeIdentifier: String?
	) {
		self.guid = guid
		self.name = name
		self.type = type

		// typeIdentifier is only in the @v11 format, which has type="standard"
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