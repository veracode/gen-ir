import Testing
@testable import gen_ir

@Test
func testPackageProductNameFromXcode26GUID() {
	#expect(Target.packageProductName(from: "PACKAGE-PRODUCT:MyLibrary") == "MyLibrary")
	#expect(Target.packageProductName(from: "PACKAGE-PRODUCT:MyLibrary--71ED4B7C0CDEC55C-dynamic") == "MyLibrary--71ED4B7C0CDEC55C-dynamic")
	#expect(Target.packageProductName(from: "PACKAGE-PRODUCT:gRPC-C++") == "gRPC-C++")
}

@Test
func testPackageProductNameFromXcode27GUID() {
	#expect(Target.packageProductName(from: "PACKAGE-PRODUCT:swift-nio_NIOCore.NIOCore") == "NIOCore")
	#expect(Target.packageProductName(from: "PACKAGE-PRODUCT:swift-nio_NIOCore.NIOCore-36BDC5FFFCFC8476-dynamic") == "NIOCore-36BDC5FFFCFC8476-dynamic")
	#expect(Target.packageProductName(from: "PACKAGE-PRODUCT:firebase-ios-sdk_FirebaseAppDistribution-Beta.FirebaseAppDistribution-Beta") == "FirebaseAppDistribution-Beta")
	#expect(Target.packageProductName(from: "PACKAGE-PRODUCT:swift-crypto__CryptoExtras._CryptoExtras-5B720A5779A85864-dynamic") == "_CryptoExtras-5B720A5779A85864-dynamic")
	#expect(Target.packageProductName(from: "PACKAGE-PRODUCT:grpc-binary_gRPC-C++.gRPC-C++") == "gRPC-C++")
}

@Test
func testPackageProductNameIgnoresOtherGUIDs() {
	#expect(Target.packageProductName(from: "PACKAGE-TARGET:NIOCore") == nil)
	#expect(Target.packageProductName(from: "PACKAGE-RESOURCE:NIOSSL") == nil)
	#expect(Target.packageProductName(from: "PRODUCTREF-PACKAGE-PRODUCT:swift-nio_NIOCore.NIOCore") == nil)
}
