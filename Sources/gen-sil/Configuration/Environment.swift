//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 27/07/2022.
//

import Foundation

typealias Arguments = [String]
typealias EnvironmentMap = [String: String]

enum Environment {
	case cli(Arguments)
	case xcode(EnvironmentMap)
}

extension Environment {
	init(environment: EnvironmentMap, arguments: Arguments) {
		if environment["XCODE_VERSION_ACTUAL"] != nil {
			self = .xcode(environment)
		} else {
			self = .cli(arguments)
		}
	}
}
