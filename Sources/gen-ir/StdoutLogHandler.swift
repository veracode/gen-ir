//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 30/08/2022.
//

import Foundation
import Logging

struct StdOutLogHandler: LogHandler {
	subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
		get {
			metadata[key]
		}
		set(newValue) {
			metadata[key] = newValue
		}
	}

	var metadata: Logging.Logger.Metadata = [:]

	var logLevel: Logging.Logger.Level = .info

	func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
		let levelPrefix = getLevelPrefix(level)
		let timestamp = getTimeStamp(level)
		let lineInfo = getLineInfo(level, source, file, function, line)

		print("\(timestamp)\(lineInfo)\(levelPrefix)\(message)")
	}

	private func getLevelPrefix(_ level: Logger.Level) -> String {
		switch level {
		case .trace:
			return "[TRACE] "
		case .debug:
			return "[DEBUG] "
		case .info:
			return ""
		case .notice:
			return "[~] "
		case .warning:
			return "[!] "
		case .error:
			return "[ERROR] "
		case .critical:
			return "[CRITICAL] "
		}
	}

	private func getTimeStamp(_ level: Logger.Level) -> String {
		switch level {
		case .trace, .debug, .notice, .warning, .error, .critical:
			return "\(Date.now) "
		case .info:
			return ""
		}
	}

	private func getLineInfo(_ level: Logger.Level, _ source: String , _ file: String, _ function: String, _ line: UInt) -> String {
		switch level {
		case .trace, .debug, .notice, .warning, .error, .critical:
			return "[\(source) \(file):\(line) \(function)] "
		case .info:
			return ""
		}
	}

	static func standard(label: String) -> StdOutLogHandler {
		Self.init()
	}
}
