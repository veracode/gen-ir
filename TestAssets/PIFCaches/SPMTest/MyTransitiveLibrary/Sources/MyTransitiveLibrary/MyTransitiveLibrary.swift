// The Swift Programming Language
// https://docs.swift.org/swift-book

import MyCommonLibrary
@_exported import Lottie

public struct MyTransitiveLibrary {
	public static let test = "This is a test \(MyCommonLibrary.common)"
	public static let lottie = LottieAnimationView()
}
