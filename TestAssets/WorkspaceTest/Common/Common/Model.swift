//
//  Model.swift
//  Common
//
//  Created by Thomas Hedderwick on 24/08/2023.
//

import Foundation

public struct Model {
	public let uuid: UUID = .init()
	public let name: String

	public init(name: String) {
		self.name = name
	}
}
