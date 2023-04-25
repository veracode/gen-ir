//
//  UserModel.swift
//  Common
//
//  Created by Thomas Hedderwick on 24/04/2023.
//

import Foundation

public struct OrgModel: Codable {
	public let login: String
	public let id: Int
	public let node_id: String
	public let url: URL
	public let repos_url: URL
	public let events_url: URL
	public let hooks_url: URL
	public let issues_url: URL
	public let members_url: URL
	public let public_members_url: URL
	public let avatar_url: URL
	public let description: String?
}
