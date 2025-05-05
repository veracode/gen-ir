//
//  FileLogHandler.swift
//

import Foundation
import Logging

struct FileTextStream: TextOutputStream {
	let fileUrl: URL
	private var fileHandle: FileHandle?

	init(filePath: String) {
		// Open the file for appending; create it if it doesn't exist
		let capturePath = filePath  + "/genir-capture.log"
		let fileManager = FileManager.default
		if !fileManager.fileExists(atPath: capturePath) {
				fileManager.createFile(atPath: capturePath, contents: nil)
		}
		self.fileUrl = URL(fileURLWithPath: capturePath)
		do {
			fileHandle = try FileHandle(forWritingTo: fileUrl)
		} catch {
			print("Failed to open file handle for \(capturePath): \(error)")
			fileHandle = nil
		}
	}

	func write(_ string: String) {
		guard let data = string.data(using: .utf8) else { return }
		fileHandle?.write(data)
	}

	func close() {
			fileHandle?.closeFile()
	}
}

public struct FileLogHandler: GenIRLogHandler {

	private let fileStream: FileTextStream

	public var metadata: Logging.Logger.Metadata = [:]
	public var logLevel: Logging.Logger.Level = .info

	public init(filePath: String) {
		fileStream = FileTextStream(filePath: filePath)
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
