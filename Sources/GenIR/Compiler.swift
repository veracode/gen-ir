//
//  Compiler.swift
//
//
//  Created by Thomas Hedderwick on 06/09/2022.
//

/// Compiler represents the various compilers supported for use with this tool
enum Compiler: String {
	case clang
	case swiftc
}

/// A CompilerCommand represents a union of the command itself and the compiler used in the command
struct CompilerCommand: Hashable {
	/// The full command as seen in the build log
	let command: String
	/// The compiler used in this command
	let compiler: Compiler
}

/// A mapping of targets to the commands used when building them
typealias TargetToCommands = [String: [CompilerCommand]]
