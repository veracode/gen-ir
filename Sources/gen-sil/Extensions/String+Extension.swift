//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 04/07/2022.
//

import Foundation

extension String {
  /// Unescapes a backslash escaped string
  /// - Parameter string: the escaped string
  /// - Returns: an unescaped string
  func unescaped() -> String {
    self.replacingOccurrences(of: "\\\\", with: "\\")
  }
}
