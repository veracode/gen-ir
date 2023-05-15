//
//  XCConfigParser.swift
//
//
//  Created by Thomas Hedderwick on 15/06/2023.
//

import Foundation

// Note: The knowledge used to create this parser largely derives from an
// incredible writeup by Samantha Demi here: https://pewpewthespells.com/blog/xcconfig_guide.html

// TODO: Do we need to support the <DEVELOPER_DIR> directive?

class XCConfigParser {
	/// Path to the XCConfig file being parsed
	let path: URL

	/// Cache of config paths to their contents.
	/// Since we parse imports lets not re-parse what has already been parsed
	private var cache: [URL: [String]] = [:]

	/// The variables of this file _and any file it includes_
	private var variables: [XCConfigVariable] = []

	/// The 'variable' contents of the config - i.e. only lines where variables are being declared
	private var contents: [String] = []

	init(path: URL) {
		self.path = path
	}

	func parse() throws {
		// Parse the contents of the files (including includes files!), looking for variables
		contents = try variableContents(of: path)

		variables = contents
			.compactMap { XCConfigVariable($0) }

		// TODO: Make it so we don't need to do this after the fact) value(for) requires that variables be instantiated...
		variables = variables.map { resolveVariable($0) }
	}

	///  Finds the value of a variable for a given variable key
	/// - Parameters:
	///   - key: the key of the variable
	///   - conditions: any conditions to be matched against conditional variable assignments
	/// - Returns: the value for the variable, if found
	func value(for key: String, constrainedBy conditions: [XCConfigCondition] = [.sdk(.iOS)]) -> String? {
		let matches = variables
			.filter { $0.key == key }
			.filter { $0.matches(conditions: conditions) }

		if matches.isEmpty {
			logger.debug("Couldn't find value for key: \(key), constrainedBy: \(conditions) in \(variables)")
			return nil
		}

		if matches.count == 1 {
			return matches.first!.value
		}

		// TODO: Attach priority to variable declarations to attempt to determine which is 'correct'
		return matches.first?.value
	}

	///  Resolves a variable's references
	/// - Parameter variable: the variable to resolve
	/// - Returns:  the resolved variable
	private func resolveVariable(_ variable: XCConfigVariable) -> XCConfigVariable {
		// Currently Supports:
		//  - X = ${Y}
		//  - FOO_${X} = ${Y}
		//  - FOO = ${X}_${Y} Z
		// Currently does _not_ support:
		//  - ${X_${Y}}
		let allowedDelimiters = [("${", "}"), ("$(", ")")]
		let variableLine = variable.line

		guard variableLine.contains(allowedDelimiters[0].0) || variableLine.contains(allowedDelimiters[1].0) else {
			return variable
		}

		func indexOfStartDelimiter(_ string: String, after: String.Index? = nil) -> String.Index? {
			string.index(ofSubstring: allowedDelimiters[0].0, after: after)
				?? string.index(ofSubstring: allowedDelimiters[1].0, after: after)
		}

		func indexOfEndDelimiter(_ string: String, after: String.Index? = nil) -> String.Index? {
			string.index(ofSubstring: allowedDelimiters[0].1, after: after) ??
				string.index(ofSubstring: allowedDelimiters[1].1, after: after)
		}

		var substituted = variable.line
		var startIndex = indexOfStartDelimiter(substituted)
		var endIndex = indexOfEndDelimiter(substituted)

		while let start = startIndex, let end = endIndex {
			let slice = substituted[substituted.index(start, offsetBy: 2)...substituted.index(before: end)]

			if let value = value(for: String(slice)) {
				substituted.replaceSubrange(start...end, with: value)

				// Since we replaced a subrange, we need to reset the indices
				startIndex = indexOfStartDelimiter(substituted)
				endIndex = indexOfEndDelimiter(substituted)
				continue
			}

			// Advance the search space
			startIndex = indexOfStartDelimiter(substituted, after: end)
			let newStartIndex = substituted.index(after: end)
			endIndex = indexOfEndDelimiter(substituted, after: newStartIndex)
		}

		guard let newVariable = XCConfigVariable(substituted) else {
			logger.debug("Couldn't create new variable from line: \(substituted).")
			return variable
		}

		return newVariable
	}

	///  Recursively resolves imports for a given file, searching included files for their includes
	/// - Parameters:
	///   - path: the path to resolve imports for
	///   - imports: a set of paths of files included
	private func resolveImports(for path: URL, with imports: inout Set<URL>) throws {
		let pathContents = try contents(of: path)
		let pathIncludes = includes(for: pathContents)
		cache[path] = pathContents
		imports.formUnion(pathIncludes)

		try pathIncludes
			.filter { cache[$0] == nil }
			.map {
				let includedContents = try contents(of: $0)
				cache[$0] = includedContents

				let foundIncludes = includes(for: includedContents)
				imports.formUnion(foundIncludes)

				return $0
			}
			.forEach { try resolveImports(for: $0, with: &imports) }
	}

	///  Parses, and resolves, include declarations to their file paths
	/// - Parameter lines: the contents of a config file
	/// - Returns: a set of resolved include paths
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

	///  Gets the contents of a given config path, ignoring comments and empty lines
	/// - Parameter path: the path to get the contents of
	/// - Returns: contents of the file at the given path, with empty lines and comments removed
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

	///  Get the variables from a file, including the variables from imported files
	/// - Parameters:
	///   - path: the path of the file to get variables for
	/// - Returns: a list of variable declarations
	private func variableContents(of path: URL) throws -> [String] {
		var imports = Set<URL>()
		try resolveImports(for: path, with: &imports)

		var allVariables = try variables(from: path)

		try imports.forEach {
			allVariables.append(contentsOf: try variables(from: $0))
		}

		return allVariables
	}

	///  Gets variable declarations from a config file
	/// - Parameter path: the path to the config file
	/// - Returns: a list of variable declarations
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
