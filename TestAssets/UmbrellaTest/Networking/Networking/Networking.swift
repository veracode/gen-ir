//
//  File.swift
//  Networking
//
//  Created by Thomas Hedderwick on 19/04/2023.
//

import Foundation

public struct Networking {
	public static func get(_ url: URL) async throws -> Data {
		let response = try await URLSession.shared.data(for: .init(url: url))

		return response.0
	}
}
