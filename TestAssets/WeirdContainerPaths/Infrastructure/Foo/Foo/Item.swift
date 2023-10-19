//
//  Item.swift
//  Foo
//
//  Created by Thomas Hedderwick on 18/10/2023.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
