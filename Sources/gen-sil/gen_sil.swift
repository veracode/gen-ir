import Foundation

// Heavily inspired by https://blog.digitalrickshaw.com/2016/03/14/dumping-the-swift-ast-for-an-ios-project-part-2.html

@main
public struct gen_sil {
  /// Runs a command returning the stdout
  /// - Parameters:
  ///   - command: the command to run
  ///   - arguments: the arguments to pass to the command
  ///   - environment: the environment variables to set
  /// - Returns: stdout of the command run
  private static func run(
    _ command: String,
    arguments: [String],
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> String {
    let pipe = Pipe()
    let process = Process()

    if #available(macOS 13.0, *) {
      process.executableURL = URL(filePath: command)
    } else {
      process.launchPath = command
    }
    process.arguments = arguments
    process.standardOutput = pipe
    process.environment = environment

    if #available(macOS 10.13, *) {
      try! process.run()
    } else {
      process.launch()
    }

    let data: Data
    if #available(macOS 10.15.4, *) {
      data = try! pipe.fileHandleForReading.readToEnd() ?? Data()
    } else {
      data = pipe.fileHandleForReading.readDataToEndOfFile()
    }

    return String(data: data, encoding: .utf8)!
  }

  /// Unescapes a backslash escaped string
  /// - Parameter string: the escaped string
  /// - Returns: an unescaped string
  private static func unescaped(string: String) -> String {
    return string.replacingOccurrences(of: "\\\\", with: "\\")
  }

  /// Attempts to match a regex pattern in a string
  /// - Parameters:
  ///   - regex: the regex pattern
  ///   - text: the text to attempt to match against
  /// - Returns: the matches
  private static func match(regex: String, in text: String) throws -> [NSTextCheckingResult] {
    let regex = try NSRegularExpression(pattern: regex)
    return regex.matches(in: text, range: NSMakeRange(0, text.count))
  }

  /// Ignores paths that containt '/build/'
  /// - Parameter array: an array of file paths
  /// - Returns: the array, without paths containing '/build/'
  private static func ignoringBuildFiles(_ array: [String]) -> [String] {
    // TODO: lol no this is terrible
    return array.filter { !$0.contains("/build/") }
  }

  public static func main() {
    // Collect environment variables
    var environment = ProcessInfo.processInfo.environment

    // HACK: Because the new Xcode build system doesn't _yet_ support -dry-run
    // we essentially have to compile twice. Have a env flag to stop the second run
    // TODO: this will need to change - is there some metadata (or xcodeproj) we can parse for the file list?
    let shouldSkip = environment["SHOULD_SKIP_GEN_SIL"] ?? "0"

    guard (shouldSkip == "0") else {
      print("============ should skip is set - skipping run ==============")
      exit(0)
    }

    // we now want to skip any new invocations of this tool
    environment["SHOULD_SKIP_GEN_SIL"] = "1"

    let projectName       = environment["PROJECT_NAME"]!
    let targetName        = environment["TARGET_NAME"]!
    let configuration     = environment["CONFIGURATION"]!
    let sdkName           = environment["SDK_NAME"]!
    let productModuleName = environment["PRODUCT_MODULE_NAME"]!
    let frameworkPath     = environment["FRAMEWORK_SEARCH_PATHS"]!.trimmingCharacters(in: .whitespacesAndNewlines)

    print("running xcodebuild from gen_sil")

    // clean the project so Xcode doesn't skip invocations of swiftc
    _ = run(
      "/usr/bin/xcrun",
      arguments: [
        "xcodebuild", "clean"
      ],
      environment: environment
    )

    // build the project
    let buildOutput = run(
      "/usr/bin/xcrun",
      arguments: [
        "xcodebuild",
        "archive",
        "-project", "\(projectName).xcodeproj",
        "-target", targetName,
        "-configuration", configuration,
        "-sdk", sdkName,
      ],
      environment: environment
    )

    let swiftcRegex = ".*/swiftc.*[\\s]+-target[\\s]+([^\\s]*).*"

    guard let targetMatch = try! match(regex: swiftcRegex, in: buildOutput).first else {
      print("No target match found!!")
      print(buildOutput)
      exit(1)
    }

    let target = (buildOutput as NSString).substring(with: targetMatch.range(at: 1))
    print("Found target match! \(target)")

    let sourceRegex = "(/([^ ]|(?<=\\\\) )*\\.swift(?<!\\\\))"

    guard let sourceMatches = try? match(regex: sourceRegex, in: buildOutput) else {
      print("No source match found!!")
      print(buildOutput)
      exit(1)
    }

    let sourceFiles = Set(ignoringBuildFiles(sourceMatches.map { unescaped(string: (buildOutput as NSString).substring(with: $0.range(at: 1))) }))
    print("------- source files ----------")
    print(sourceFiles)

    for sourceFile in sourceFiles {
      let filename = ((sourceFile as NSString).lastPathComponent as String)

      var arguments = [
        "-sdk",
        sdkName,
        "swiftc",
        "-emit-sil",
        "-o", "/Users/thedderwick/Desktop/sil/\(filename).sil",
        "-F", frameworkPath,
        "-target", target,
        "-module-name", productModuleName,
        sourceFile
      ]

      // HACK: see https://github.com/apple/swift/issues/55127
      // TODO: improve this check by looking for @main or other attributes
      if filename == "AppDelegate.swift" {
        arguments.append("-parse-as-library")
      }

      let silResult = run("/usr/bin/xcrun", arguments: arguments)
      print(silResult)
    }

    exit(0)
  }
}
