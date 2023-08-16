//
//  Module.swift
//  LargerModule
//
//  Created by Jared Carlson on 8/2/23.
//

import Foundation
import SwiftMath

func guess() -> Int {
    let variable = Int.random(in: 1..<1000)
    return sub(lhs:1000, rhs: variable)
}




