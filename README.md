# gen-sil

This package is designed to wrap an xcodebuild run to generate SIL or LLVM IR artefacts for each file in the project.

It does this by parsing calls to the compiler, and rerunning them with the appropriate flags, then collating the files together.

## TODO

This is a PoC project, and as such requires a _lot_ more attention & investigation. Things identified so far:

- The tool requires that a project is cleaned, then built, THEN we run a build
  - This is inefficient and will anger users who have long build times
  - Find a way around this, parsing the input files etc.
- Write a good test suite!!!!
- We currently append a flag for 'AppDelegate.swift' files as they use @main or similar
  - We should probably parse the content of the files looking for @main or retry on failures with an error containing this
- Make the codebase more maintainable by breaking up logical pieces 
- Add verbose/developer logging
- Output path is currently hardcoded

