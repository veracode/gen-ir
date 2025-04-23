import XCTest
import Foundation
import Testing
@testable import gen_ir

@Test
func testWarnOnMultipleBuilds() throws {
	let logContent: [String] = [
		"Build description path: /Users/ur/Library/Developer/Xcode/DrvdData/Exper1-etmk/Build/Intermediates.noindex/ArchiveIntermediates/Experimental1/IntermediatePath/XCBuildData/65828f.xcbuilddata",
		"",
		"SwiftDriver Experimental1 normal arm64 com.apple.xcode.tools.swift.compiler (in target 'Experimental1' from project 'Experimental1')",
		"    cd /p",
		"    builtin-SwiftDriver -- /swiftc build command",
	  "",
		"** ARCHIVE SUCCEEDED **",
		" ",
		"Build description path: /Users/ur/Library/Developer/Xcode/DrvdData/Exper1-etmk/Build/Intermediates.noindex/ArchiveIntermediates/Experimental1/IntermediatePath/XCBuildData/65828f.xcbuilddata",
		"",
		"** ARCHIVE SUCCEEDED **"
		]
		let logParser = XcodeLogParser(log: logContent)
		try logParser.parse()
		#expect(logParser.commandLog.count == 1)
		#expect(logParser.buildCount == 2)
}
