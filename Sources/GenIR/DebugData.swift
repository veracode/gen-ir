import Foundation
import ArgumentParser // To use ValidationError
import LogHandlers
import Logging

///
/// This file contains the DebugData struct, which is responsible for capturing debug data during the execution of the program.
///  It includes methods for initializing the capture path and logging relevant information. The data is captured in a sub-directory
///  of the xcarchive and therefore will be included with the submission to the Veracode Platform.
/// 
///  The struct is initialized with the xcarchive and a flag indicating whether debug data is to be captured.
///  The directory structure will be:
/// 	- xcarchive
/// 		- debug-data
/// 		- Gen-IR log output file.
/// 		- xcodebuild log which was input to Gen-IR
/// 		- PIF cache directory
/// 		- xcode-select ouput
/// 		- xcodebuild --version output
/// 		- swift --version output
/// 		- env | grep DEVELOPER_DIR output
/// 		- data.zip
/// 
struct DebugData: Decodable {

	let capturePath: URL
	let logDataPath: URL

	init (xcodeArchivePath: URL) throws {

		// 	Setup the capture path to hold the debug data. This path is a sub-directory of the xcarchive. 
		capturePath = xcodeArchivePath.appendingPathComponent("debug-data", isDirectory: true)

		// Make sure the directory to hold debug data exists and is empty
		if !FileManager.default.directoryExists(at: capturePath) {
			// It doesn't exist, so create it
			try FileManager.default.createDirectory(at: capturePath, withIntermediateDirectories: true)
		}

		// Create a subdirectory for the logs and add a file log handler to write the log there.
		let zipLogPath = capturePath.appendingPathComponent("log")
		try FileManager.default.createDirectory(at: zipLogPath, withIntermediateDirectories: true)

		logDataPath = zipLogPath.appendingPathComponent("genir-capture.log", isDirectory: false)
	}

	///
	/// Tell the user what information will be captured.
	///
	public func displayCaptureInfo() {
		let captureInfo = Logger.Message(
		"""
		\n
		\u{001B}[1m The Gen-IR capture option is enabled.\u{001B}[0m
		The following data will be added to the xcarchive and sent to Veracode:
		- Gen-IR log output file
		- xcodebuild log which was input to Gen-IR
		- PIF cache directory and its contents
		- The location of the developer directory (e.g. /Applications/Xcode.app/Contents/Developer)
		    This is obtained via the xcode-select -p command and from the value of the DEVELOPER_DIR environment variable.
			  No other environment variables are captured.
		- The xcodebuild version
		- The swift-version
		\n
		""")
		GenIRLogger.logger.info(captureInfo)
		GenIRLogger.logger.info("Debug data will be captured to: \(capturePath)")
	}

	///
	///	Capture the execution context:
	/// This includes the xcodebuild log, the configured developer directory, the xcodebuild version, and the swift version.
	/// 
	public func captureExecutionContext(logPath: URL) throws {

		// Capture the xcodebuild log
		try FileManager.default.copyItem(at: logPath, to: capturePath.appendingPathComponent("xcodebuild.log"))

		// Capture the configured developer directory
		let developerDir = try execShellCommand(command: "xcode-select", args: ["-p"])

		// Capture a possible override of the developer directory
		let developerDirOverride = ProcessInfo.processInfo.environment["DEVELOPER_DIR"] ?? "Not set"

		// Capture the xcodebuild version
		let xcodeBuildVersion = try execShellCommand(command: "xcodebuild", args: ["-version"])

		// Capture the swift version
		let swiftVersion = try execShellCommand(command: "swift", args: ["-version"])

		do {
			let versionsUrl = capturePath.appendingPathComponent("versions.txt")
			FileManager.default.createFile(atPath: versionsUrl.path, contents: nil)
			let versionsFile = try FileHandle(forWritingTo: versionsUrl)
			versionsFile.write(Data("""
				DEVELOPER_DIR: \(developerDir)\n
				DEVELOPER_DIR_OVERRIDE: \(developerDirOverride)\n
				XCODEBUILD_VERSION: \(xcodeBuildVersion)\n
				SWIFT_VERSION: \(swiftVersion)\n
				""".utf8))
			versionsFile.closeFile()
		} catch {
			GenIRLogger.logger.error("Debug data capture Error \(error) occurred creating the versions.txt file while capturing debug data.")
		}
		GenIRLogger.logger.info("Debug data capture execution context data captured.")
	}

	/// 
	/// Capture the PIF cache:
	/// This is a copy of the PIF cache from the location specified in the xcarchive.
	/// The location is determined by the PIFCache.pifCachePath(in:) method.
	/// 
	public func capturePIFCache(pifLocation: URL) throws {

		// Capture the PIF cache
		let savedPif = capturePath.appendingPathComponent("pif-data")
    do {
        // Perform the copy operation and skip broken symlinks
        try copyDirectorySkippingBrokenSymlinks(from: pifLocation, to: savedPif)
    } catch {
        GenIRLogger.logger.error("Debug data capture of PIF Cache error: \(error.localizedDescription)")
    }
		GenIRLogger.logger.info("Debug data capture PIF cache data captured.")
	}

	/// 
	/// Do any final data captures and log the completion message.
	/// 
	public func captureComplete(xcarchive: URL) throws {
		GenIRLogger.logger.info("Debug data capture complete.")
	}

	/// 
	/// Copy a directory and skip broken symlinks.
	/// This is used to copy the PIF cache from the location based on the build cache path parsed from the xcode build log.
	/// The location is determined by the PIFCache.pifCachePath(in:) method.
	/// 
	private func copyDirectorySkippingBrokenSymlinks(from sourceURL: URL, to destinationURL: URL) throws {

			let fileManager = FileManager.default
			let contents = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [])
			let sourceBaseName = sourceURL.path.hasSuffix("/") ? sourceURL.path : sourceURL.path + "/"

			for item in contents {
					let resourceValues = try item.resourceValues(forKeys: [.isSymbolicLinkKey])

					if resourceValues.isSymbolicLink == true {
							// Check if the symlink target exists
							let targetPath = try fileManager.destinationOfSymbolicLink(atPath: item.path)
							if !fileManager.fileExists(atPath: targetPath) {
									GenIRLogger.logger.info("Skipping broken symlink while copying PIFCache: \(item.path)")
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
							GenIRLogger.logger.error("Error while copying a PIFCache item \(item) : \(error.localizedDescription)")
							continue
					}
			}
	}

	/// 
	/// Given a command string and it's arguments, invoke a shell to execute the command and return the command output.
	/// 
	private func execShellCommand(command: String, args: [String]) throws -> String {
		let result: Process.ReturnValue
		do {
			result = try Process.runShell(command, arguments: args, runInDirectory: FileManager.default.currentDirectoryPath.fileURL)
		} catch {
			GenIRLogger.logger.error(
				"""
				Debug data capture couldn't create process for command: \(command) with arguments: \(args.joined(separator: " ")). \
				Output will not be captured.
				"""
			)
			return ""
		}

		if result.code != 0 {
			GenIRLogger.logger.error(
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
