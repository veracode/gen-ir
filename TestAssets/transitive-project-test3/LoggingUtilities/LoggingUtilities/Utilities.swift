//
//  Utilities.swift
//  LoggingUtilities
//
//  Created by Jared Carlson on 8/16/23.
//

import Foundation
import Logger

struct LogWriter {
    
    var level:String
    let logger:Logger
    
    public init(level:String) {
        self.level = level
        self.logger = Logger()
    }
    
    public func log(msg:String) {
        self.logger.log(msg: msg)
    }
}
