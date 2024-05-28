//
//  StdoutLogHandler.swift
//
//
//  Created by Thomas Hedderwick on 30/08/2022.
//

import Foundation
import Logging

/// All module logger (yes because swift-log hasn't really solved for setting level globally without passing an instance around everywhere)
public var logger = Logger(label: "LogHandler", factory: StdIOStreamLogHandler.init)

struct StdIOTextStream: TextOutputStream {
	static let stdout = StdIOTextStream(file: Darwin.stdout)
	static let stderr = StdIOTextStream(file: Darwin.stderr)

	let file: UnsafeMutablePointer<FILE>

	func write(_ string: String) {
		var string = string
		string.makeContiguousUTF8()
		string.utf8.withContiguousStorageIfAvailable { bytes in
			flockfile(file)
			defer { funlockfile(file) }

			fwrite(bytes.baseAddress!, 1, bytes.count, file)

			fflush(file)
		}
	}
}

public struct StdIOStreamLogHandler: LogHandler {
	internal typealias SendableTextOutputStream = TextOutputStream & Sendable

	private let stdout = StdIOTextStream.stdout

	public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
		get { metadata[key] }
		set(newValue) { metadata[key] = newValue }
	}

	public var metadata: Logging.Logger.Metadata = [:]
	public var logLevel: Logging.Logger.Level = .info

	public init() {}

	public init(_: String) {}

	// periphery:ignore:parameters count
	// swiftlint:disable:next function_parameter_count
	public func log(
		level: Logger.Level,
		message: Logger.Message,
		metadata: Logger.Metadata?,
		source: String,
		file: String,
		function: String,
		line: UInt
	) {
		let lineInfo = lineInfo(for: level, file: file, function: function, line: line)

		stdout.write("\(timestamp)\(lineInfo)\(levelPrefix)\(message)\n")
	}

	private var levelPrefix: String {
		switch logLevel {
		case .trace:
			return "[TRACE] "
		case .debug:
			return "[DEBUG] "
		case .info:
			return ""
		case .notice, .warning:
			return "[~] "
		case .error:
			return "[!] "
		case .critical:
			return "[!!!] "
		}
	}

	private var timestamp: String {
		switch logLevel {
		case .trace, .debug, .notice, .warning, .error, .critical:
			return "\(Date.now) "
		case .info:
			return ""
		}
	}

	private func lineInfo(for level: Logger.Level, file: String, function: String, line: UInt) -> String {
		switch level {
		case .trace, .debug, .notice, .warning, .error, .critical:
			return "[\(file):\(line) \(function)] "
		case .info:
			return ""
		}
	}
}
