//
//  Versions.swift
//
//
//  Created by Thomas Hedderwick on 12/09/2022.
//
// History:
// 2026-nn-nn - 1.0.2 -- SSAST-11722 don't fail on TargetDependency decode failure.
// 2026-01-08 - 1.0.1 -- Use info logging to allow user to monitor progress.
// 2025-12-01 - 1.0.0 -- Don't chase through Dynamic Dependencies
// 2025-09-19 - 0.5.4 -- Update release doc; warn multiple builds; capture debug data
// 2025-04-18 - 0.5.3 -- PIF Tracing; log unique compiler commands
// 2025-04-09 - 0.5.2 -- PIF sort workspace; log instead of throw
// 2024-09-17 - 0.5.1
// 2024-09-16 - 0.5.0 -- Process based on the PIF cache instead of project files.
import Foundation

enum Versions {
	static let version = "1.0.2"
}
