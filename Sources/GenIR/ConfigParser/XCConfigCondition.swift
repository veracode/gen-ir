//
//  XCConfigCondition.swift
//
//
//  Created by Thomas Hedderwick on 15/06/2023.
//

enum XCConfigCondition {
	/// Unable to parse the configuration
	case unknown

	/// The arch type being constrained
	case arch(XCConfigArch)

	/// The sdk being constrained
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
			self = .arch(.from(value: value))
		case "sdk":
			self = .sdk(.from(value: value))
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

extension XCConfigCondition: CustomStringConvertible {
	var description: String {
		var result = "XCConfigCondition("

		switch self {
		case .unknown:
			result.append("unknown")
		case .arch(let arch):
			result.append("arch(\(arch))")
		case .sdk(let sdk):
			result.append("sdk(\(sdk))")
		case .config(let config):
			result.append("config(\(config))")
		case .variant:
			result.append("variant")
		case .dialect:
			result.append("dialect")
		}

		return result.appending(")")
	}
}

extension XCConfigCondition: Equatable {
	public static func == (lhs: XCConfigCondition, rhs: XCConfigCondition) -> Bool {
		switch lhs {
		case .arch(let arch):
			switch rhs {
			case .arch(let rhsArch):
				return arch == rhsArch || arch == .any || rhsArch == .any
			default:
				return false
			}
		case .sdk(let sdk):
			switch rhs {
			case .sdk(let rhsSdk):
				return sdk == rhsSdk || sdk == .any || rhsSdk == .any
			default:
				return false
			}
		case .config(let config):
			switch rhs {
			case .config(let rhsConfig):
				return config == rhsConfig
			default:
				return false
			}
		case .variant:
			return rhs == .variant
		case .dialect:
			return rhs == .dialect
		case .unknown:
			return rhs == .unknown
		}
	}
}
