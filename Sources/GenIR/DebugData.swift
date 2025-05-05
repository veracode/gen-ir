import LogHandlers
import Foundation
import ArgumentParser // To use ValidationError

/*
 This file contains the DebugData struct, which is responsible for capturing debug data during the execution of the program.
 It includes methods for initializing the capture path, zipping the captured data, and logging relevant information. Initially, 
 to avoid adding dependencies, we will use NFileCoordinator to zip the directory. This API does not have amy way to add to an 
 existing zip file, so we will copy all data to the directory supplied in capturePath before zipping it.

 The struct is initialized with a directory referred to as capturePath. The value is saved in the zipBasePath property.
 The directory structure will be:
	- zipBasePath
		- data
			- Gen-IR log output file.
			- xcodebuild log which was input to Gen-IR
			- PIF cache directory
			- xcode-select ouput
			- xcodebuild --version output
			- swift --version output
			- env | grep DEVELOPER_DIR output
			- copy of the xcarchive folder
		- data.zip
*/
struct DebugData {

	let captureDebugData: Bool
	var zipBasePath: URL
	var zipCollectionPath: URL

	init (capturePath: URL?, xcodeLogPath: URL) throws {
		// Determine whether we should capture debug data
		guard let zipPath = capturePath else {
			captureDebugData = false
			zipBasePath = URL(fileURLWithPath: "")
			zipCollectionPath = URL(fileURLWithPath: "")
			return
		}

		// Make sure the directory to hold debug data exists and is empty
		if !FileManager.default.directoryExists(at: zipPath) {
			try FileManager.default.createDirectory(at: zipPath, withIntermediateDirectories: true)
		} else {
			if FileManager.default.contents(atPath: zipPath.absoluteString) != nil {
				throw ValidationError("Path \(zipPath) is not empty! The directory to capture debug data must be empty.")
			}
		}

		// Create a subdirectory for the logs and add a file log handler to write the log there.
		self.zipBasePath = zipPath
		self.zipCollectionPath = zipPath.appendingPathComponent("data")
		let zipLogPath = zipCollectionPath.appendingPathComponent("log")
		try FileManager.default.createDirectory(at: zipLogPath, withIntermediateDirectories: true)
		
		logger.info("Debug data will be captured to: \(zipLogPath)")
		var captureLog = FileLogHandler(filePath: zipLogPath.filePath)
		captureLog.logLevel = logger.logLevel
		MultiLogHandler.addHandler(captureLog)

		captureDebugData = true

		try collectExecutionContext(logPath: xcodeLogPath)
	}

	private func collectExecutionContext(logPath: URL) throws {

		// Collect the xcodebuild log
		try FileManager.default.copyItem(at: logPath, to: zipCollectionPath.appendingPathComponent("xcodebuild.log"))

		// Collect the configured developer directory
		let developerDir = "DEVELOPER_DIR: " + ( try execShellCommand(command: "xcode-select", args: ["-p"]) )

		// Collect a possible override of the developer directory
		let developerDirOverride = ProcessInfo.processInfo.environment["DEVELOPER_DIR"] ?? "Not set"

		// Collect the xcodebuild version
		let xcodeBuildVersion = try execShellCommand(command: "xcodebuild", args: ["-version"])

		// Collect the swift version
		let swiftVersion = try execShellCommand(command: "swift", args: ["-version"])

		do {
				let versionsUrl = zipCollectionPath.appendingPathComponent("versions.txt")
				try developerDir.write(to: versionsUrl, atomically: true, encoding: .utf8)
				let versionsFile = try FileHandle(forWritingTo: versionsUrl)
				versionsFile.seekToEndOfFile()
				versionsFile.write("DEVELOPER_DIR_OVERRIDE: \(developerDirOverride)\n".data(using: .utf8)!)
				versionsFile.write("XCODEBUILD_VERSION: \(xcodeBuildVersion)\n".data(using: .utf8)!)
				versionsFile.write("SWIFT_VERSION: \(swiftVersion)\n".data(using: .utf8)!)
				versionsFile.closeFile()
		} catch {
			logger.error("Debug data capture Error \(error) occurred creating the versions.txt file while capturing debug data.")
		}
		logger.info("Debug data capture execution context data collected.")
	}

	public func collectPIFCache(pifLocation: URL) throws {
		if !captureDebugData {
			return
		}

		let pifCachePath = try PIFCache.pifCachePath(in: pifLocation)
		// Collect the PIF cache
		let savedPif = zipCollectionPath.appendingPathComponent("pif-data")
    let fileManager = FileManager.default

    do {
        // Ensure the source directory exists
        guard fileManager.fileExists(atPath: pifCachePath.path) else {
            logger.error("Debug data capture PIF Cache location \(pifLocation) does not exist.")
            return
        }

        // Perform the copy operation
				// Using this routine because NSFileCoordinator was failing on broken symlinks.  I couldn't find a way to get it to not follow symlinks.
        try copyDirectorySkippingBrokenSymlinks(from: pifCachePath, to: savedPif)
    } catch {
        logger.error("Debug data capture of PIF Cache error: \(error.localizedDescription)")
    }
		logger.info("Debug data capture PIF cache data collected.")
	}

	public func collectComplete(xcarchive: URL) throws {
		if !captureDebugData {
			return
		}

		// Collect the xcarchive
		try collectXcarchive(xcarchive: xcarchive)
		try  debugDataZip()
		logger.info("Debug data capture complete.")
	}
	
	/*
		zip up the root directory
		This method is synchronous and the block will be executed before it returns.
		If the method fails, the block will not be executed though
		If you expect the archiving process to take long, execute it on another queue
	*/
	private func debugDataZip() throws {
		// Zip the debug data
		let fm = FileManager.default
	 
		// this will hold the URL of the zip file
		var archiveUrl: URL?	
		var error: NSError?
		// if we encounter an error, store it here
		let coordinator = NSFileCoordinator()
	 
		coordinator.coordinate(readingItemAt: zipCollectionPath, options: [.forUploading], error: &error) { (zipUrl) in
		// coordinator.coordinate(readingItemAt: zipCollectionPath, options: [], error: &error) { (zipUrl) in
			// zipUrl points to the zip file created by the coordinator
			// zipUrl is valid only until the end of this block, so we move the file to a temporary folder
			let tmpUrl = try! fm.url(
			for: .itemReplacementDirectory,
				in: .userDomainMask,
				appropriateFor: zipUrl,
				create: true
			).appendingPathComponent("genir-debug-data.zip", isDirectory: false)
			try! fm.copyItem(at: zipUrl, to: tmpUrl)
		
			// store the URL so we can use it outside the block
			archiveUrl = tmpUrl
		}
	 

		if let archiveUrl = archiveUrl {
			// Copy the zip file to the user specified location
			let resultUrl = zipBasePath.appendingPathComponent("genir-debug-data.zip")
			try FileManager.default.copyItem(at: archiveUrl, to: resultUrl)
			logger.info("NSFileCoordinator output: \(archiveUrl)")
			logger.info("Debug data captured to: \(resultUrl)")
		} else {
			logger.error("Debug data capture failed zipping the debug data: \(error?.localizedDescription ?? "Unknown error")")
		}
	}

	func copyDirectorySkippingBrokenSymlinks(from sourceURL: URL, to destinationURL: URL) throws {

			let fileManager = FileManager.default
			let contents = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [])
			let sourceBaseName = sourceURL.path.hasSuffix("/") ? sourceURL.path : sourceURL.path + "/"

			for item in contents {
					let resourceValues = try item.resourceValues(forKeys: [.isSymbolicLinkKey])
					
					if resourceValues.isSymbolicLink == true {
							// Check if the symlink target exists
							let targetPath = try fileManager.destinationOfSymbolicLink(atPath: item.path)
							if !fileManager.fileExists(atPath: targetPath) {
									logger.info("Skipping broken symlink while copying PIFCache: \(item.path)")
									continue
							}
					}
					// Find the relative path of the item
					let relativePart = item.path.replacingOccurrences(of: sourceBaseName, with: "")

					// Define destination path
					let destinationItemURL = destinationURL.appendingPathComponent(relativePart)
					let parentDestinationURL = destinationItemURL.deletingLastPathComponent()
					do {
						// Make sure the destination directory exists
						try fileManager.createDirectory(at: parentDestinationURL, withIntermediateDirectories: true)
						// Copy item
						try fileManager.copyItem(at: item, to: destinationItemURL)
					} catch {
							logger.error("Error while copying a PIFCache item \(item) : \(error.localizedDescription)")
							continue
					}
			}
	}

	private func collectXcarchive(xcarchive: URL) throws {
		// Collect the xcarchive
		let archiveName = xcarchive.lastPathComponent
		let archiveDestination = zipCollectionPath.appendingPathComponent(archiveName)
		do {
			try FileManager.default.copyItem(at: xcarchive, to: archiveDestination)
		} catch {
			logger.error("Debug data capture of xcarchive error: \(error.localizedDescription)")
		}
		logger.info("Debug data capture xcarchive data collected.")
	}

	private func execShellCommand(command: String, args: [String]) throws -> String {
		let result: Process.ReturnValue
		do {
			result = try Process.runShell(command, arguments: args, runInDirectory: FileManager.default.currentDirectoryPath.fileURL)
		} catch {
			logger.error(
				"""
				Debug data capture couldn't create process for command: \(command) with arguments: \(args.joined(separator: " ")). \
				Output will not be captured.
				"""
			)
			return ""
		}

		if result.code != 0 {
			logger.error(
			"""
			Debug data capture command finished with non-zero exit code. Output will not be captured.
				- code: \(result.code)
				- command: \(command) \(args.joined(separator: " "))
				- stdout: \(String(describing: result.stdout))
				- stderr: \(String(describing: result.stderr))
			"""
			)

			return ""
		}

		return result.stdout ?? ""
	}
}