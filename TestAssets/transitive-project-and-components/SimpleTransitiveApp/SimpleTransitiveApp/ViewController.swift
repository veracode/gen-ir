//
//  ViewController.swift
//  SimpleTransitiveApp
//
//  Created by Jared Carlson on 7/27/23.
//

import UIKit
import SwiftCalc

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let ninth_fib = Fibonacci(n: 9)
        print("The ninth fibonacci number is \(ninth_fib)")
    }


}

