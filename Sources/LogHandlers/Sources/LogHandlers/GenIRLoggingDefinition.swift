import Foundation
import Logging

/// All module logger (yes because swift-log hasn't really solved for setting level globally without passing an instance around everywhere)
public class GenIRLogger {
	private static var internalLogger: Logger?

	/// The logger for the GenIR module. This is a singleton instance that can be used to log messages throughout the module.
	public static var logger: Logger {
		get {
			return internalLogger ?? Logger(label: "Gen-IR")
		}
		set {internalLogger = newValue }
	}
}

/// A protocol that defines a logging handler for GenIR.
public protocol GenIRLogHandler: LogHandler {

	var levelPrefix: String { get }

	var timestamp: String { get }

	func lineInfo(for level: Logger.Level, file: String, function: String, line: UInt) -> String

	// swiftlint:disable:next function_parameter_count
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

	/// Add, change, or remove metadata for this handler. Metadata is a dictionary of key-value pairs which can be
	/// used to add additional information to log messages.
	public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
		get { metadata[key] }
		set(newValue) { metadata[key] = newValue }
	}

	/// Convert a log level to a string prefix for the log message.
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

	/// Add a timestamp to the log message based on the log level.
	public var timestamp: String {
		switch logLevel {
		case .trace, .debug, .notice, .warning, .error, .critical:
			return "\(Date.now) "
		case .info:
			return ""
		}
	}

	/// Add line information to the log message based on the log level.
	public func lineInfo(for level: Logger.Level, file: String, function: String, line: UInt) -> String {
		switch level {
		case .trace, .debug, .notice, .warning, .error, .critical:
			return "[\(file):\(line) \(function)] "
		case .info:
			return ""
		}
	}

	// swiftlint:disable function_parameter_count 
	/// Log a message with the specified log level, message, metadata, source, file, function, and line number.
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
		print("\(timestamp)\(lineInfo)\(levelPrefix)\(message)\n")
	}
	// swiftlint:enable function_parameter_count 
}
