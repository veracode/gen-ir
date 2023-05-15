struct XCConfigSDK: OptionSet {
	let rawValue: Int8

	static let unknown = XCConfigSDK(rawValue: 1 << 0)
	static let macOS = XCConfigSDK(rawValue: 1 << 1)
	static let iOS = XCConfigSDK(rawValue: 1 << 2)
	static let iOSSimulator = XCConfigSDK(rawValue: 1 << 3)

	static let any: XCConfigSDK = [.macOS, .iOS, .iOSSimulator]

	static func from(value: String) -> XCConfigSDK {
		if value == "*" {
			return .any
		} else if value.starts(with: "iphoneossimulator") {
			// NOTE: This _has_ to be before iphoneos or it'll match that
			return .iOSSimulator
		} else if value.starts(with: "iphoneos") {
			return .iOS
		} else if value.starts(with: "macosx") {
			return .macOS
		} else {
			logger.error("Invalid XCConfig SDK condition: \(value). Setting to .unknown")
			return .unknown
		}
	}
}

extension XCConfigSDK: CustomStringConvertible {
	var description: String {
		var result = "XCConfigSDK("

		switch self {
		case .unknown:
			result.append("unknown")
		case .macOS:
			result.append("macOS")
		case .iOSSimulator:
			result.append("iphoneossimulator")
		case .iOS:
			result.append("iphoneos")
		case .any:
			result.append("*")
		default:
			assert(true, "should have handled all cases")
			result.append("default")
		}

		return result.appending(")")
	}
}
