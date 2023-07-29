//
//  Calculation.swift
//  SwiftCalculation
//
//  Created by Jared Carlson on 7/28/23.
//

import Foundation
import SwiftMath

public func Fibonacci( n: Int ) -> Int {
    var a = 0
    var b = 1
    var c = 0
    for _ in 2...n {
        c = add(lhs: a, rhs: b)
        a = b
        b = c
    }
    return b
}
