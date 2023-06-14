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

	init(label: String) { }

	// swiftlint:disable function_parameter_count
	func log(
		level: Logger.Level,
		message: Logger.Message,
		metadata: Logger.Metadata?,
		source: String,
		file: String,
		function: String,
		line: UInt
	) {
		let levelPrefix = prefix(for: level)
		let timestamp = timestamp(for: level)
		let lineInfo = lineInfo(for: level, source: source, file: file, function: function, line: line)

		print("\(timestamp)\(lineInfo)\(levelPrefix)\(message)")
	}
	// swiftlint:enable function_parameter_count

	private func prefix(for level: Logger.Level) -> String {
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
			return "[~] "
		case .error:
			return "[!] "
		case .critical:
			return "[!!!] "
		}
	}

	private func timestamp(for level: Logger.Level) -> String {
		switch level {
		case .trace, .debug, .notice, .warning, .error, .critical:
			return "\(Date.now) "
		case .info:
			return ""
		}
	}

	private func lineInfo(for level: Logger.Level, source: String, file: String, function: String, line: UInt) -> String {
		switch level {
		case .trace, .debug, .notice, .warning, .error, .critical:
			return "[\(file):\(line) \(function)] "
		case .info:
			return ""
		}
	}
}
