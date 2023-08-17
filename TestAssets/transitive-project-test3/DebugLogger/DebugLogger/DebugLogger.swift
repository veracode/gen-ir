//
//  DebugLogger.swift
//  DebugLogger
//
//  Created by Jared Carlson on 8/16/23.
//

import Foundation
import Logger


struct LogWriter {
    
    var level:String
    let logger:Logger
    
    public init() {
        self.level = "debug"
        self.logger = Logger()
    }
    
    public func log(msg:String) {
        let message = "\(self.level): \(msg)"
        self.logger.log(msg: message)
    }
}
