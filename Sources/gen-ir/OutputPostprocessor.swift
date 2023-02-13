//
//  OutputPostprocessor.swift
//  
//
//  Created by Thomas Hedderwick on 08/02/2023.
//

import Foundation
import pbxproj_parser


/// The `OutputPostprocessor` is responsible for trying to match the IR output of the `CompilerCommandRunner` with the products in the `xcarchive`.
/// The `CompilerCommandRunner` will output IR with it's product name, but doesn't take into account the linking of products into each other.
/// The `OutputPostprocessor` attempts to remedy this by using the `ProjectParser` to detect depenendencies between products AND
/// parsing the `xcarchive` to determine if something was statically linked, and if so, copies the IR for that product into the linker's IR folder.
///
/// Things to account for:
/// 	* MACH_O_TYPE != my_dylib
/// 	* Embed Frameworks Phase (PBXCopyFilesBuildPhase using a file ref that relates to the framework being copied)
/// 		* If this is set to not embed, then the result will be statically linked into the dependee
///
///
/// Now you might think - man this is hacky as hell - and you'd be right, but I haven't found a nicer way of doing this
struct OutputPostprocessor {
	let project: ProjectParser
	let xcarchive: URL
	let output: URL
	let dynamicFrameworksToPaths: [String: URL]
	let productsToPaths: [String: URL]

	init(project: ProjectParser, xcarchive: URL, output: URL) throws {
		self.project = project
		self.xcarchive = xcarchive
		self.output = output

		// Get a mapping of framework names to the paths inside of the xcarchive (i.e. all the dynamically linked frameworks)
		dynamicFrameworksToPaths = try FileManager.default.filteredContents(of: xcarchive.appendingPathComponent("Products")) { path in
			let attributes = try path.resourceValues(forKeys: [.isDirectoryKey])
			return attributes.isDirectory ?? false && path.lastPathComponent == "Frameworks"
		}
		.flatMap {
			try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)
				.filter{ $0.lastPathComponent.hasSuffix(".framework") }
		}
		.reduce(into: [String: URL](), { partialResult, url in
			let name = url.deletingPathExtension().lastPathComponent
			partialResult[name] = url
		})

		productsToPaths = try FileManager.default.directories(at: output)
			.reduce(into: [String: URL](), { partialResult, path in
				partialResult[path.lastPathComponent] = path
			})
	}

	func process() throws {
		var pathsToRemove = [URL]()

		for (target, path) in productsToPaths {
			pathsToRemove.append(contentsOf: try moveDependencies(for: target, to: path))
		}

		// TODO: remove 'static' deps so we don't duplicate them in the submission?
	}

	private func moveDependencies(for target: String, to path: URL) throws -> [URL] {
		let dependencies = project.dependencies(for: target)

		return try dependencies
			.map { $0.fileURL.deletingPathExtension().lastPathComponent } // get the name of the dependency
			.filter { dynamicFrameworksToPaths[$0] != nil } // if this dependency is dynamic, we can ignore it - we want IR as a seperate item
			.compactMap { name in
				// Copy the contents to the target directory
				if let dependencyPath = productsToPaths[name] {
					try FileManager.default.copyItemMerging(at: dependencyPath, to: path)
					return dependencyPath
				}

				logger.error("Failed to get path for depenedency: \(name)")
				return nil
			}
	}
}
