//
//  StdoutLogHandler.swift
//
//
//  Created by Thomas Hedderwick on 30/08/2022.
//

import Foundation
import Logging

struct StdIOTextStream: TextOutputStream {
	static let stdout = StdIOTextStream(file: Darwin.stdout)

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

public struct StdIOStreamLogHandler: GenIRLogHandler {

	private let stdout = StdIOTextStream.stdout

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
