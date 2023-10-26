//
//  TargetParser.swift
//		Parse a TARGET file (used when building) to match targets to the build manifest
//
//  Created by Kevin Rise on 10/19/23
//

// heavily inspired from https://github.com/polac24/XCBuildAnalyzer.git

import Foundation

//import Logging

public struct TargetManifest: Codable {
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

public struct TargetParser {
	private let decoder: JSONDecoder

	public init() {
		decoder = JSONDecoder()
	}

	public func process(_ url: URL) throws -> TargetManifest {
		let data = try Data(contentsOf: url)
		return try decoder.decode(TargetManifest.self, from: data)
	}
}