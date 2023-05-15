//
//  XCConfig.swift
//
//
//  Created by Thomas Hedderwick on 15/06/2023.
//

struct XCConfigVariable {
	/// The variables key
	let key: String
	/// The variables value
	let value: String
	/// The original, unprocessed line the variable was declared with
	let line: String

	/// Any conditions attached to this variable declaration
	/// See: https://pewpewthespells.com/blog/xcconfig_guide.html#ConditionalVariableAssignment
	let conditions: [XCConfigCondition]

	init?(_ line: String) {
		// TODO: Once we bump the minimum target to macOS 13, try Swift Regex here
		guard let equalsIndex = line.firstIndex(of: "=", ignoringElementBetween: "[", and: "]") else { return nil }

		self.line = line

		let keyPart = line[..<equalsIndex]
		value = String(line[line.index(after: equalsIndex)..<line.endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)

		if let bracketIndex = line.firstIndex(of: "[") {
			// We have some conditions to parse along with the 'key'
			key = String(line[..<bracketIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
			conditions = Self.parseConditions(line[bracketIndex...equalsIndex])
		} else {
			key = String(keyPart).trimmingCharacters(in: .whitespacesAndNewlines)
			conditions = []
		}
	}

	func matches(conditions conditionsToMatch: [XCConfigCondition]) -> Bool {
		guard !conditionsToMatch.isEmpty && !conditions.isEmpty else { return true }

		for matchCondition in conditionsToMatch {
			for condition in conditions where condition == matchCondition {
				return true
			}
		}

		return false
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

				// expecting something like [key=value,key=value,key=value]
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
