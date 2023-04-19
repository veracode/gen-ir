//
//  Orgs.swift
//  Models
//
//  Created by Thomas Hedderwick on 19/04/2023.
//

import Foundation

public struct Orgs: Codable {
	let login: String
	let id: Int
	let node_id: String
	let url: URL
	let repos_url: URL
	let events_url: URL
	let hooks_url: URL
	let issues_url: URL
	let members_url: URL
	let public_members_url: URL
	let avatar_url: URL
	let description: String?
}
