//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 27/07/2022.
//

import Foundation

protocol Configuration {
	var output: URL { get }
}

enum ConfigurationError: Swift.Error {
	case configurationError(message: String)
	case wrongConfiguration(String)
}
