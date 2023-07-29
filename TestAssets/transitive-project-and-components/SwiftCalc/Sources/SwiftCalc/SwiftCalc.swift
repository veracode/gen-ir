// The Swift Programming Language
// https://docs.swift.org/swift-book

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