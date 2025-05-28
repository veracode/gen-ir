//
//  FileLogHandler.swift
//

import Foundation
import Logging

public struct FileLogHandler: GenIRLogHandler {

	private let fileStream: GenIrIoTextStream

	public var metadata: Logging.Logger.Metadata = [:]
	public var logLevel: Logging.Logger.Level = .info

	public init(filePath: URL) {
		fileStream = GenIrIoTextStream(file: fopen(filePath.path, "w"))
	}

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
		fileStream.write("\(timestamp)\(lineInfo)\(levelPrefix)\(message)\n")
	}
}
