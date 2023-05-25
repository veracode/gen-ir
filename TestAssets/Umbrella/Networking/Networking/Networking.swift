//
//  Networking.swift
//  Networking
//
//  Created by Thomas Hedderwick on 24/04/2023.
//

import Foundation


public struct Networking {
	static public func get(_ url: URL) async throws -> Data {
		let request = URLRequest(url: url)
		let (data, _) = try await URLSession.shared.data(for: request)

		return data
	}
}
