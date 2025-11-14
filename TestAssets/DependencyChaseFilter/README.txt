Test project in TestApp77.xcworkspace (built originally with Xcode 16.1).


TestApp77 (app target) depends on TestLibraryA (framework target) and TestLibraryC (framework target)

TestLibraryA (framework target) depends on TestLibraryB (framework target)

TestLibraryB (framework target) depends on the opentelemetry-swift package.

TestLibraryC (framework target) has no dependencies.



Generated archive is in build/test.xcarchive.


---
See that the IR files from the opentelemetry-swift package (e.g., ZipkinBaggagePropagator.bc) appear in all targets,
except for TestLibraryC (which doesn't have a transitive dependency on opentelemetry-swift).

However, the files should only appear in IR/TestLibraryB, which is the target that references the package. You can
check that only Products/Applications/TestApp77.app/Frameworks/TestLibraryB.framework/TestLibraryB contains symbols
from opentelemetry-swift (e.g., using the `nm` utility).

Why is this a problem? The size of the IR folder is bloating the app:

$ du -chd 1 build/test.xcarchive/IR
 26M	build/test.xcarchive/IR/TestApp77.app
 26M	build/test.xcarchive/IR/TestLibraryB.framework
4.0K	build/test.xcarchive/IR/TestLibraryC.framework
 26M	build/test.xcarchive/IR/TestLibraryA.framework
 78M	build/test.xcarchive/IR
 78M	total


This app has no actual contents: only TestLibraryB should have anything of
significance from the opentelemetry-swift package (26M), and everything else
should be ~4K. However, we're getting the 26M from opentelemetry-swift multiplied
across all transitive dependencies, which for a big app with ~200 frameworks, can
be multiple gigabytes of extra space.

In particular, we're seeing our zipped app archive go above the 2GiB upload limit!


---
Build command:

rm -rf ./build && xcodebuild clean -workspace TestApp77.xcworkspace -scheme TestApp77 -derivedDataPath ./build && xcodebuild archive -derivedDataPath ./build -workspace TestApp77.xcworkspace -scheme TestApp77 -configuration Debug -destination generic/platform=iOS -archivePath build/test.xcarchive > build_log.txt


Gen-IR command:

gen-ir build_log.txt build/test.xcarchive --debug > gen_ir_log.txt
