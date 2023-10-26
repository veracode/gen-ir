//
//  BuildManifestParser.swift
//
//
//  Created by Kevin Rise on 10/19/23
//

// heavily inspired from https://github.com/polac24/XCBuildAnalyzer.git

import Foundation
import Logging
import enum PBXProjParser.TargetType

public struct BuildOutputHandler {
	private let manifestFinder = ManifestFinder()
	private var manifestLocation: ManifestLocation?

	public init(project: URL, scheme: String, targets: inout [GenTarget]) {


		// move this out to gen-ir??
			// find the manifest file, then hand off to the parser

		// then, walk the list of targets and using the manifest, create the IR code for each target


		// given a workspace or project file, find the build manifest

		do { 
			manifestLocation = try manifestFinder.findLatestManifest(options: .build(project: project, scheme: scheme))

			logger.info("Found build manifest \(manifestLocation!.manifest)")
			logger.info("Found PIFCache \(manifestLocation!.pifCache!)")

			// get the GUIDs for each target
			let fm = FileManager.default
			let targetParser = TargetParser()
			do {
				let files = try fm.contentsOfDirectory(at: manifestLocation!.pifCache!, includingPropertiesForKeys: nil)

				for file in files {
					print("found file \(file)")
					
					do {
						let targetManifest = try targetParser.process(file)

						logger.debug("Target manifest: \(targetManifest)")

						// add guid into GenTarget
						// probably a more elegant way to do this, but with only a small number of targets to process...
						// TODO: fix/guard - handle optional
						let targetType = getTargetType(targetManifest.productTypeIdentifier)

						for index in 0..<targets.count {
							if targets[index].buildTarget.type == targetType && targets[index].buildTarget.name == targetManifest.name {
								targets[index].guid = targetManifest.guid
								break
							}

						}


					} catch {
						logger.error("Error parsing target manifest \(file)")
					}
				}
			} catch {
				logger.error("Error reading TARGET files")
			}

			// get the manifest into readable JSON format
			

			// return

		} catch let error as ManifestFinderError {
			logger.error("\(error.errorDescription!) \n\n \(error.recoverySuggestion!)")

			// return / throw error
		} catch {
			logger.error("\(error.localizedDescription)")

			// return / throw error
		}

	}

	// TODO: clean up.  use last part only?
	private func getTargetType(_ typeName: String?) -> TargetType{
		switch typeName {
			case "com.apple.product-type.application":
				return TargetType.Application
			case "com.apple.product-type.framework":
				return TargetType.Framework
			case "wrapper.cfbundle":
				return TargetType.Bundle
			case "wrapper.app-extension":
				return TargetType.Extension
			default:
				return TargetType.Unknown
		}
	}

}