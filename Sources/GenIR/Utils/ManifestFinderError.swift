//
//  ManifestFinderError.swift
//  BuildAnalyzer
//
//  Created by Bartosz Polaczyk on 9/11/23.
//

import Foundation

enum ManifestFinderError: Error, LocalizedError {
	case projectDictionaryNotFound(lookupLocations: [URL])
	case manifestNotFound
	case unknownPackageFormat(URL, Error?)
	case invalidFileFormat(URL)
	case otherError(Error)

	var errorDescription: String? {
		switch self {
		case .projectDictionaryNotFound: "Cannot find DerivedData for a project"
		case .invalidFileFormat: "The format is not supported"
		case .unknownPackageFormat: "Unexpected Package.swift format"
		case .manifestNotFound: "Xcode-generated manifest files has not been found"
		default: "Build manifest json file reading error"
		}
	}

	var recoverySuggestion: String? {
		switch self {
		case .projectDictionaryNotFound(let dirs):
			return "Make sure your DerivedData dir exists at any of these directories: \n\(dirs.map(\.path).joined(separator: ",\n"))"
		case .invalidFileFormat(let url): return "The file \(url.path) is not supported. Please open .xcodeproj, .xcworkspace, Package.swift, .playground or raw manifest.json/-manifest.xcbuild"
		default:
			return "Make sure you built at least once from Xcode"
		}
	}
}
