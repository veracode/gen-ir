# gen-ir

`gen-ir` is a tool designed to extract LLVM IR from an Xcode build process. 

It does this by parsing calls to the compiler, and rerunning them with the appropriate flags to generate the IR.

## Requirements for use

`gen-ir` requires that a **full** build log is provided. 

That means a clean, fresh build of a project. The reason behind this the compiler won't make calls for artifacts that are already generated and don't need to be touched again. So using this with a non-clean build may result in modules being missed.

## Building

In a shell, change into the project directory and run:

```sh
swift build
```

The tool will be output to `.build/debug/gen-ir`

## TODO

See `gen_ir.swift` for a list of outstanding TODOs
