//
//  LargerModule.swift
//  LargerModule
//
//  Created by Jared Carlson on 8/2/23.
//

import Foundation
import SwiftCalc

func fib_guess( ) -> Int {
    let fib = Fibonacci(n: Int.random(in: 0...10))
    return (fib + Int.random(in: 0...10))
}

