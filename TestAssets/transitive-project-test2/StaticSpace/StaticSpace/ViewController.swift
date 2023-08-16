//
//  ViewController.swift
//  StaticSpace
//
//  Created by Jared Carlson on 8/16/23.
//

import UIKit
import Utils

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let a = 4
        let b = 3
        let sum = addInts(lhs: a, rhs: b)
        print("The sum is \(sum)")
    }


}

