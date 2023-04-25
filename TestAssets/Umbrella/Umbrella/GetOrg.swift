//
//  GetOrg.swift
//  Umbrella
//
//  Created by Thomas Hedderwick on 24/04/2023.
//

import Foundation
import Common
import Networking

enum Error: Swift.Error {
	case invalidUser
}

public func getOrg(_ username: String) async throws -> OrgModel {
	guard let url = URL(string: "https://api.github.com/users/\(username)/orgs") else {
		throw Error.invalidUser
	}

	let data = try await Networking.get(url)
	let model = try JSONDecoder().decode(OrgModel.self, from: data)

	return model
}
