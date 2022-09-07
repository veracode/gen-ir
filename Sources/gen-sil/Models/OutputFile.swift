//
//  File.swift
//  
//
//  Created by Thomas Hedderwick on 29/07/2022.
//

import Foundation

typealias OutputFileMap = [String: OutputFileContents]

struct OutputFileContents: Codable {
	let diagnostics: URL
	let swiftDependencies: URL

	let emitModuleDependencies: URL?
	let emitModuleDiagnostics: URL?

	let dependencies: URL?
	let indexUnitOutputPath: URL?
	let llvmBc: URL?
	let object: URL?
	let swiftModule: URL?

	private enum CodingKeys: String, CodingKey {
		case dependencies
		case diagnostics
		case indexUnitOutputPath = "index-unit-output-path"
		case llvmBc = "llvm-bc"
		case object
		case swiftDependencies = "swift-dependencies"
		case swiftModule = "swiftmodule"
		case emitModuleDependencies = "emit-module-dependencies"
		case emitModuleDiagnostics = "emit-module-diagnostics"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		if #available(macOS 13.0, *) {
			diagnostics = URL(filePath: try container.decode(String.self, forKey: .diagnostics))
			swiftDependencies = URL(filePath: try container.decode(String.self, forKey: .swiftDependencies))

			if let emitModuleDependencies = try container.decodeIfPresent(String.self, forKey: .emitModuleDependencies) {
				self.emitModuleDependencies = URL(filePath: emitModuleDependencies)
			} else {
				self.emitModuleDependencies = nil
			}

			if let emitModuleDiagnostics = try container.decodeIfPresent(String.self, forKey: .emitModuleDiagnostics) {
				self.emitModuleDiagnostics = URL(filePath: emitModuleDiagnostics)
			} else {
				emitModuleDiagnostics = nil
			}

			if let dependencies = try container.decodeIfPresent(String.self, forKey: .dependencies) {
				self.dependencies = URL(filePath: dependencies)
			} else {
				self.dependencies = nil
			}

			if let indexUnitOutputPath = try container.decodeIfPresent(String.self, forKey: .indexUnitOutputPath) {
				self.indexUnitOutputPath = URL(filePath: indexUnitOutputPath)
			} else {
				self.indexUnitOutputPath = nil
			}

			if let llvmBc = try container.decodeIfPresent(String.self, forKey: .llvmBc) {
				self.llvmBc = URL(filePath: llvmBc)
			} else {
				self.llvmBc = nil
			}

			if let object = try container.decodeIfPresent(String.self, forKey: .object) {
				self.object = URL(filePath: object)
			} else {
				self.object = nil
			}

			if let swiftModule = try container.decodeIfPresent(String.self, forKey: .swiftModule) {
				self.swiftModule = URL(filePath: swiftModule)
			} else {
				self.swiftModule = nil
			}
		} else {
			diagnostics = URL(fileURLWithPath: try container.decode(String.self, forKey: .diagnostics))
			swiftDependencies = URL(fileURLWithPath: try container.decode(String.self, forKey: .swiftDependencies))

			if let emitModuleDependencies = try container.decodeIfPresent(String.self, forKey: .emitModuleDependencies) {
				self.emitModuleDependencies = URL(fileURLWithPath: emitModuleDependencies)
			} else {
				self.emitModuleDependencies = nil
			}

			if let emitModuleDiagnostics = try container.decodeIfPresent(String.self, forKey: .emitModuleDiagnostics) {
				self.emitModuleDiagnostics = URL(fileURLWithPath: emitModuleDiagnostics)
			} else {
				emitModuleDiagnostics = nil
			}

			if let dependencies = try container.decodeIfPresent(String.self, forKey: .dependencies) {
				self.dependencies = URL(fileURLWithPath: dependencies)
			} else {
				self.dependencies = nil
			}

			if let indexUnitOutputPath = try container.decodeIfPresent(String.self, forKey: .indexUnitOutputPath) {
				self.indexUnitOutputPath = URL(fileURLWithPath: indexUnitOutputPath)
			} else {
				self.indexUnitOutputPath = nil
			}

			if let llvmBc = try container.decodeIfPresent(String.self, forKey: .llvmBc) {
				self.llvmBc = URL(fileURLWithPath: llvmBc)
			} else {
				self.llvmBc = nil
			}

			if let object = try container.decodeIfPresent(String.self, forKey: .object) {
				self.object = URL(fileURLWithPath: object)
			} else {
				self.object = nil
			}

			if let swiftModule = try container.decodeIfPresent(String.self, forKey: .swiftModule) {
				self.swiftModule = URL(fileURLWithPath: swiftModule)
			} else {
				self.swiftModule = nil
			}
		}
	}
}

