<h1 align="center">
  <br>Gen IR 🧞‍♂️<br>
</h1>

<h4 align="center">
  Generate LLVM IR from an Xcode Build Log
</h4>

This tool was heavily inspired by: https://blog.digitalrickshaw.com/2016/03/14/dumping-the-swift-ast-for-an-ios-project-part-2.html ❤️

## ⚠️ Before you use

It's important to know that `gen-ir` requires that a **full** build log is provided.

**This means a clean, fresh build of a project.**

The compiler will **not** make a call for an object that doesn't need to be rebuilt, and we will not be able to parse what doesn't exist. Ensure you do a clean before your build otherwise `gen-ir` may miss some modules.

## Usage

Run `gen-ir --help` for the latest usage.

`gen-ir` takes a Xcode build log by two means, a path to a file or stdin:

```bash
# Path to build log (you can export from inside of Xcode too)
xcodebuild clean && xcodebuild build -project TestProject.xcodeproj -scheme TestProject -configuration Debug > build_log.txt
gen-ir build_log.txt ir_files/

# Stdin (you may need to redirect stderr to stdout here, Xcode is weird about writing to it sometimes)
xcodebuild clean && xcodebuild build -project TestProject.xcodeproj -scheme TestProject -configuration Debug | gen-ir - ir_files/
```

## Requirements

- macOS 12+
- Xcode 14+

## Installing

### Homebrew

A tap is available for `gen-ir`:

```bash
brew tap ninjalikescheez/tap
brew install gen-ir
```

## Building

In a shell, change into the project directory and run:

```sh
swift build
```

The tool will be output to `.build/debug/gen-ir`

## TODO

- Documentation
