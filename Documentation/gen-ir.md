# ``gen_ir``

Generate LLVM IR from an Xcode Build Log 🧞‍♂️

## Overview

`gen-ir` takes a Xcode build log and extracts the compiler commands used, modifies them, and reruns them to produce bitcode for each file in a project.

It accepts input via log file or stdin.

> Important to Note:
> The compiler will not run commands if it doesn't need to. This means unless you have a **full** build log (i.e. from a cleaned state) `gen-ir` will not see all of the commands used to generate the project and may miss some modules because of that. It is advised that you perform a clean before generating the build log used by this tool.

## Topics

### Compiler Command Extraction

- ``XcodeLogParser``

### Compiler Command Models & Running

- ``Compiler``
- ``CompilerCommand``
- ``CompilerCommandRunner``
- ``TargetsAndCommands``
- ``OutputFileMap``

### Logging

- ``logger``
- ``StdOutLogHandler``

### Tool Specific

- ``IREmitterCommand``
- ``Versions``
- ``BuildCacheManipulator``
- ``OutputPostprocessor``
- ``Target``
- ``Targets``
