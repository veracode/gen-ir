//
//  StdoutLogHandler.swift
//
//
//  Created by Thomas Hedderwick on 30/08/2022.
//

import Foundation
import Logging

public struct StdIOStreamLogHandler: GenIRLogHandler {
	let stdout = GenIrIoTextStream(file: Darwin.stdout)

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
}
