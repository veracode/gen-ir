import Foundation
import Testing
@testable import PIFSupport

struct PIFTests {
    private let testBundlePath: URL

    init() throws {

        let fileManager = FileManager.default
        let currentDirectoryPath = fileManager.currentDirectoryPath
        testBundlePath = URL(fileURLWithPath: "\(currentDirectoryPath)/PIF/Tests/Resources/PIFCache")

        try #require(fileManager.fileExists(atPath: testBundlePath.path()))
    }

    @Test("validate PIF name") func name() throws {
			let expectedWorkspace: URL = URL(string: "\(testBundlePath.absoluteString)workspace/WORKSPACE@v11_hash=d3da8d031e363802ae5f57500452c641_subobjects=1ba277b88fb5c402e35936acc0a7292f-json")!
			try #expect(PIFCacheParser.workspacePath(in: testBundlePath) == expectedWorkspace )
    }
}
