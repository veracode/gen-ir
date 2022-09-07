# gen-sil

This package is designed to wrap an xcodebuild run to generate SIL or LLVM IR artefacts for each file in the project.

It does this by parsing calls to the compiler, and rerunning them with the appropriate flags, then collating the files together.

## TODO

This is a PoC project, and as such requires a _lot_ more attention & investigation. See `gen_ir.swift` for a list of TODOs
