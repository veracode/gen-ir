//
//  Framework.swift
//  Framework
//
//  Created by Thomas Hedderwick on 24/08/2023.
//

import SwiftUI
import Common
import SFSafeSymbols

public struct Framework {
	public let uuid: UUID = UUID()
	public let model: Model
	public let icon: Image

	public init(model: Model) {
		self.model = model
		self.icon = .init(systemSymbol: .globe)
	}
}
