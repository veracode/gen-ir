import Foundation

struct XCConfigParser {
	let path: URL

	private var contents: [String]

	private var configs: [String: [String]] = [:]

	init(path: URL) throws {
		self.path = path

		contents = try String(contentsOf: path)
			.components(separatedBy: .newlines)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

		try resolveImports()
	}

	private mutating func resolveImports() throws {
		// get initial imports
		var imports = includes(for: contents)

		// for each import, visit it and build an idea of it's imports too
		try imports
			.filter { configs[$0] == nil }
			.map { path.deletingLastPathComponent().appendingPathComponent($0) }
			.map { path in
				let contents = try String(contentsOf: path)
					.components(separatedBy: .newlines)
					.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

				configs[path.lastPathComponent] = contents
				return contents
			}
			.forEach { imports.formUnion(includes(for: $0)) }
			// .map { path in
			// 	let contents = try String(contentsOf: path)
			// 		.components(separatedBy: .newlines)
			// 		.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

			// 	configs[path.lastPathComponent()] = contents

			// 	return contents
			// }
			// .forEach { imports.formUnion(includes(for: $0)) }

		print(imports)
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
}
