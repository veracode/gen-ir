//
//  ViewController.swift
//  TransitiveTestApp
//
//  Created by Jared Carlson on 7/28/23.
//

import UIKit
import SwiftCalculation


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let ninth_fib = Fibonacci(n: 9)
        print("The ninth fibonacci number is \(ninth_fib)")
    }


}

