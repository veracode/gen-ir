# PBXProjParser

As the name alludes to, this package handles parsing a pbxproj via xcodeproj or xcworkspace folders.

It also contains some helper functions and structures to wrap an API around a pretty terrible file format, as well as an executable target for testing locally.

## Note

A _lot_ of the parsing is hidden behind a compiler flag for a couple reasons:

- This is a largely undocumented format, and what little documentation is out there is often either slightly wrong or outdated.
- Only a handful of information is required for `Gen IR` so to speed things up/have less decoding issues we don't parse most of the files although the structures exist to do so
