//
//  BuildTarget.swift
//
//
//  Created by Kevin Rise on 10/11/23
//

import Foundation

/// Represents a build target we need to process
public struct BuildTarget {

    let name: String
    let productName: String
    let frPath: String
    let type: TargetType

    enum TargetType {
        case Application
        case Framework
        case Bundle
        case Unknown
    }

    public init(name: String, productName: String, fileRef: PBXFileReference) {
        self.name = name
        self.productName = productName
        self.frPath = fileRef.path
        self.type = Self.getType(typeName: fileRef.explicitFileType)

    }

    private static func getType(typeName: String?) -> TargetType{
        switch typeName {
            case "wrapper.application":
                return TargetType.Application
            case "wrapper.framework":
                return TargetType.Framework
            case "wrapper.cfbundle":
                return TargetType.Bundle
            default:
                return TargetType.Unknown
        }
    }


}