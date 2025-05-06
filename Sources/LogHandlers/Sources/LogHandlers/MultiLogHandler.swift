import Foundation
import Logging

public struct MultiLogHandler: GenIRLogHandler {

	public var metadata: Logger.Metadata = [:]

	public var logLevel: Logger.Level = .info {
		didSet {
			for index in MultiLogHandler.handlers.indices {
				MultiLogHandler.handlers[index].logLevel = logLevel
			}
		}
	}

	private static var handlers: [GenIRLogHandler] = []

	public init(_: String) {
		MultiLogHandler.handlers.append(StdIOStreamLogHandler())
	}

	public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
			get {
					MultiLogHandler.handlers.first?.metadata[key]
			}
			set(newValue) {
					for var handler in MultiLogHandler.handlers {
							handler.metadata[key] = newValue
					}
			}
	}

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
			for handler in MultiLogHandler.handlers {
					handler.log(level: level, message: message, metadata: metadata, source: source, file: file, function: function, line: line)
			}
	}

	public static func addHandler(_ handler: GenIRLogHandler) {
			MultiLogHandler.handlers.append(handler)
	}
}
