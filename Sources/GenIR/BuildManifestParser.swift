//
//  BuildManifestParser.swift
//
//
//  Created by Kevin Rise on 10/19/23
//

// heavily inspired from https://github.com/polac24/XCBuildAnalyzer.git

import Foundation
import Logging

public struct BuildManifestParser {
	private let manifestFinder = ManifestFinder()
	private var manifestLocation: ManifestLocation?

	public init(project: URL, scheme: String) {
		// given a workspace or project file, find the build manifest

		do { 
			manifestLocation = try manifestFinder.findLatestManifest(options: .build(project: project, scheme: scheme))

			logger.info("Found build manifest \(manifestLocation!.manifest)")

		} catch let error as ManifestFinderError {
			logger.error("\(error.errorDescription!) \n\n \(error.recoverySuggestion!)")

			// return / throw error
		} catch {
			logger.error("\(error.localizedDescription)")

			// return / throw error
		}



	}
}