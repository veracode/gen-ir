import Foundation

// TODO: Do we need to support the <DEVELOPER_DIR> directive?

class XCConfigParser {
	let path: URL

	private var cache: [URL: [String]] = [:]

	init(path: URL) {
		self.path = path
	}

	func parse() throws -> XCConfig {
		// First, resolve all imports, including transitives
		var imports = Set<URL>()
		try resolveImports(for: path, with: &imports)

		// Next, we want to get all the variables from this file AND it's included files
		try variableContents(of: path, concatenating: imports)
			.map { XCConfigVariable($0) }

		return .init(attributes: [:], includes: [])
	}

	private func resolveImports(for path: URL, with imports: inout Set<URL>) throws {
		let pathContents = try contents(of: path)
		let pathIncludes = includes(for: pathContents)
		cache[path] = pathContents
		imports.formUnion(pathIncludes)

		let paths = pathIncludes
			.filter { cache[$0] == nil }

		try paths
			.map {
				let includedContents = try contents(of: $0)
				cache[$0] = includedContents

				let foundIncludes = includes(for: includedContents)
				imports.formUnion(foundIncludes)

				return $0
			}
			.forEach { try resolveImports(for: $0, with: &imports) }
	}

	private func includes(for lines: [String]) -> Set<URL> {
		lines
			.filter { $0.starts(with: "#include") }
			.map({ line in
				let startIndex = line.index(after: line.firstIndex(of: "\"") ?? line.startIndex)
				return String(line[startIndex..<line.index(before: line.endIndex)])
			})
			.map { path.deletingLastPathComponent().appendingPathComponent($0) }
			.reduce(into: Set<URL>(), { $0.insert($1) })
	}

	private func contents(of path: URL) throws -> [String] {
		if let contents = cache[path] {
			return contents
		}

		return try String(contentsOf: path)
			.components(separatedBy: .newlines)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty } // ignore empty lines
			.filter { !$0.starts(with: "//") } // ignore comment-only lines
	}

	private func variableContents(of path: URL, concatenating imports: Set<URL>) throws -> [String] {
		// For every file, concatenate it's contents together - ignoring anything that isn't a variable assignment
		var allVariables = try variables(from: path)

		for path in imports {
			allVariables.append(contentsOf: try variables(from: path))
		}

		return allVariables
	}

	private func variables(from path: URL) throws -> [String] {
		var allowedStartOfVariableNames = CharacterSet.alphanumerics
		allowedStartOfVariableNames.formUnion(.init(charactersIn: "_"))

		return try contents(of: path)
			.filter {
				$0.first!.unicodeScalars.allSatisfy { allowedStartOfVariableNames.contains($0) }
			}
			.filter { $0.contains("=") }
	}
}

struct XCConfig {
	let attributes: [String: String]
	let includes: [String]
}

enum XCConfigArch {
	case unknown
	case intel
	case arm
	case any

	init(_ value: String) {
		if value == "*" {
			self = .any
		} else if value.starts(with: "arm") {
			self = .arm
		} else if value == "i386" || value == "x86_64" {
			self = .intel
		} else {
			self = .unknown
		}
	}
}

enum XCConfigSDK {
	case macOS(String)
	case iOS(String)
	case iOSSimulator(String)
	case any

	init(_ value: String) {
		if value == "*" {
			self = .any
		} else if value.starts(with: "iphoneos") {
			self = .iOS(value)
		} else if value.starts(with: "iphonesimulator") {
			self = .iOSSimulator(value)
		} else if value.starts(with: "macosx") {
			self = .macOS(value)
		} else {
			logger.error("Invalid XCConfig SDK condition: \(value). Setting to .any")
			self = .any
		}
	}
}

enum XCConfigCondition {
	/// Unable to parse the configuration
	case unknown

	/// The arch type being constrained
	case arch(XCConfigArch)

	case sdk(XCConfigSDK)

	/// Config Name
	case config(String)

	/// Shouldn't be used
	case variant

	/// Shouldn't be used
	case dialect

	init(key: String, value: String) {
		switch key {
		case "arch":
			self = .arch(.init(value))
		case "sdk":
			self = .sdk(.init(value))
		case "config":
			self = .config(value)
		case "variant":
			self = .variant
		case "dialect":
			self = .dialect
		default:
			logger.debug("Unknown condition parsed: \(key): \(value)")
			self = .unknown
		}
	}
}

struct XCConfigVariable {
	let key: String
	let value: String

	let conditions: [XCConfigCondition]

	init?(_ line: String) {
		// Parse a line to a config variable declaration
		// TODO: This is a perfect place to try Swift Regex... when we can drop support for macOS 12
		guard let equalsIndex = line.firstIndex(of: "=", ignoringElementBetween: "[", and: "]") else { return nil }

		let keyPart = line[..<equalsIndex]
		value = String(line[line.index(after: equalsIndex)..<line.endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)

		if let bracketIndex = line.firstIndex(of: "[") {
			// We have some conditions to parse along with the 'key'
			key = String(line[..<bracketIndex])
			conditions = Self.parseConditions(line[bracketIndex...equalsIndex])
		} else {
			key = String(keyPart)
			conditions = []
		}
	}

	static private func parseConditions(_ part: Substring) -> [XCConfigCondition] {
		// conditions come in 3 flavours - singular, combined, & why don't we have both
		// Singular: [key=value]. i.e. [sdk=iphoneos*]
		// Combined: [key=value,key=value]. i.e. [sdk=iphoneos*,arch=arm64]
		// Why don't we have both: [key=value,key=value][key=value]. i.e. [sdk=iphoneos*,arch=arm64][arch=x86_64]

		var startIndex = part.firstIndex(of: "[")
		var endIndex = part.firstIndex(of: "]")
		var results = [XCConfigCondition]()

		while let start = startIndex, let end = endIndex {
			let slice = part[start...end]

			if slice.contains(",") {
				// Combined

				//expecting something like [key=value,key=value,key=value]
				let configs = slice
					.dropFirst()
					.dropLast()
					.split(separator: ",")
					.compactMap { assignment -> (String, String)? in
						let split = assignment.split(separator: "=")
						if split.count != 2 {
							logger.debug("Split on '=' didn't produce a key and value for: \(assignment) as part of: \(slice)")
							return nil
						}
						return (String(split[0]), String(split[1]))
					}
					.map { XCConfigCondition(key: $0.0, value: $0.1) }

					print(configs)
					results.append(contentsOf: configs)
			} else {
				// Singular

				// expecting something like [key=value]
				let keyAndValue = slice
					.dropFirst()
					.dropLast()
					.split(separator: "=")
					.map { String($0) }

				guard keyAndValue.count == 2 else {
					logger.debug("Split on '=' didn't produce a key and value... \(slice)")
					continue
				}

				results.append(XCConfigCondition(key: keyAndValue[0], value: keyAndValue[1]))
			}

			// move search space along
			let nextStartIndex = part.index(after: end)
			startIndex = nextStartIndex
			endIndex = part.index(of: "]", after: nextStartIndex)
		}

		return results
	}
}
