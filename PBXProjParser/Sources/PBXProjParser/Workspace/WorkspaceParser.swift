//
//  WorkspaceParser.swift
//
//
//  Created by Thomas Hedderwick on 18/10/2023.
//

import Foundation

struct Workspace {
	private(set) var fileReferences: [FileRef] = []
	private(set) var groupReferences: [Group] = []
}

struct WorkspaceParser {
	static func parse(_ path: URL) throws -> Workspace {
		// Parse the `contents.xcworkspacedata` (XML) file and get the list of projects
		let contentsPath = path.appendingPathComponent("contents.xcworkspacedata")

		let data = try Data(contentsOf: contentsPath)
		let delegate = WorkspaceDataParserDelegate()
		let parser = XMLParser(data: data)
		parser.delegate = delegate
		parser.parse()

		return .init(
			fileReferences: delegate.fileReferences,
			groupReferences: delegate.groupReferences
		)
	}
}

private class WorkspaceDataParserDelegate: NSObject, XMLParserDelegate {
	private(set) var fileReferences: [FileRef] = []
	private(set) var groupReferences: [Group] = []

	static let supportedElements = [Group.elementName, FileRef.elementName]

	private var groupPath: [Group] = []

	func parser(
		_ parser: XMLParser,
		didStartElement elementName: String,
		namespaceURI: String?,
		qualifiedName qName: String?,
		attributes attributeDict: [String: String] = [:]
	) {
		guard Self.supportedElements.contains(elementName) else {
			logger.debug("Skipping parsing of unsupported element: \(elementName)")
			return
		}

		guard
			let location = attributeDict["location"]
		else {
			logger.debug("Location attribute for element \(elementName) is nil, this shouldn't be the case: \(attributeDict)")
			return
		}

		do {
			switch elementName {
			case Group.elementName:
				let group = try Group(location: location, name: attributeDict["name"])
				groupPath.append(group)
				groupReferences.append(group)
			case FileRef.elementName:
				let file = try FileRef(location: location, enclosingGroup: groupPath.last)
				fileReferences.append(file)
				groupPath.last?.references.append(file)
			// Ignore any element that doesn't match the search space
			default:
				break
			}
		} catch {
			logger.debug("Parsing element: \(elementName) failed. Reason: \(error)")
		}
	}

	func parser(
		_ parser: XMLParser,
		didEndElement elementName: String,
		namespaceURI: String?,
		qualifiedName qName: String?
	) {
		guard elementName == Group.elementName else { return }
		groupPath.removeLast()
	}
}
