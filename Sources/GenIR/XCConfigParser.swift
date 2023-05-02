import Foundation

struct XCConfigParser {
	let path: URL

	private var contents: [String]

	private var configs: [URL: [String]] = [:]

	init(path: URL) throws {
		self.path = path

		contents = try String(contentsOf: path)
			.components(separatedBy: .newlines)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

		var imports = Set<String>()
		try resolveImports(for: path, with: &imports)
		print("imp: \(imports)")
	}

	private mutating func resolveImports(for path: URL, with imports: inout Set<String>) throws {
		let pathContents = try contents(of: path)
		let pathIncludes = includes(for: pathContents)
		configs[path] = pathContents
		imports.formUnion(pathIncludes)

		let paths = pathIncludes
			.map { path.deletingLastPathComponent().appendingPathComponent($0) }
			.filter { configs[$0] == nil }

		try paths
			.map {
				let includedContents = try contents(of: $0)
				configs[$0] = includedContents

				let foundIncludes = includes(for: includedContents)
				imports.formUnion(foundIncludes)

				return $0
			}
			.forEach { try resolveImports(for: $0, with: &imports) }
	}

	private func includes(for lines: [String]) -> Set<String> {
		lines
			.compactMap({ line in
				guard line.starts(with: "#include") else { return nil }

				let startIndex = line.index(after: line.firstIndex(of: "\"") ?? line.startIndex)
				return String(line[startIndex..<line.index(before: line.endIndex)])
			})
			.reduce(into: Set<String>(), { $0.insert($1) })
	}

	private func contents(of path: URL) throws -> [String] {
		try String(contentsOf: path)
			.components(separatedBy: .newlines)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
	}
}

struct XCConfig {
	let attributes: [String: String]
	let includes: [String]
}
