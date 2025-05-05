import Foundation
import Logging

/// All module logger (yes because swift-log hasn't really solved for setting level globally without passing an instance around everywhere)
public var logger = Logger(label: "LogHandler", factory: MultiLogHandler.init)

public protocol GenIRLogHandler: LogHandler {

	subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? { get set }

	var levelPrefix: String { get }

	var timestamp: String { get }

	/// The log level for this handler.
	var logLevel: Logger.Level { get set }

	/// The metadata for this handler.
	var metadata: Logger.Metadata { get set }

	func lineInfo(for level: Logger.Level, file: String, function: String, line: UInt) -> String

	func log(
		level: Logger.Level,
		message: Logger.Message,
		metadata: Logger.Metadata?,
		source: String,
		file: String,
		function: String,
		line: UInt
	)
}

extension GenIRLogHandler {

	public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
		get { metadata[key] }
		set(newValue) { metadata[key] = newValue }
	}

	public var levelPrefix: String {
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

	public var timestamp: String {
		switch logLevel {
		case .trace, .debug, .notice, .warning, .error, .critical:
			return "\(Date.now) "
		case .info:
			return ""
		}
	}

	public func lineInfo(for level: Logger.Level, file: String, function: String, line: UInt) -> String {
		switch level {
		case .trace, .debug, .notice, .warning, .error, .critical:
			return "[\(file):\(line) \(function)] "
		case .info:
			return ""
		}
	}

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
		print ("\(timestamp)\(lineInfo)\(levelPrefix)\(message)\n")
	}
}
