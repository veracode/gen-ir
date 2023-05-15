//
//  XCConfigArch.swift
//
//
//  Created by Thomas Hedderwick on 15/06/2023.
//

struct XCConfigArch: OptionSet {
	let rawValue: Int8

	static let unknown = XCConfigArch(rawValue: 1 << 0)
	// 32 (i3286) or 64 (x86_64) intel architecture
	static let intel = XCConfigArch(rawValue: 1 << 1)
	// any arm architecture
	static let arm = XCConfigArch(rawValue: 1 << 2)

	static let any: XCConfigArch = [.intel, .arm]

	static func from(value: String) -> XCConfigArch {
		if value == "*" {
			return any
		} else if value.starts(with: "arm") {
			return arm
		} else if value == "i386" || value == "x86_64" {
			return intel
		}

		return unknown
	}
}

extension XCConfigArch: CustomStringConvertible {
	var description: String {
		var result = "XCConfigArch("

		switch self {
		case .unknown:
			result.append("unknown")
		case .intel:
			result.append("intel")
		case .arm:
			result.append("arm")
		case .any:
			result.append("*")
		default:
			assert(true, "Case should have been handled")
			result.append("default")
		}

		return result.appending(")")
	}
}
