// The Swift Programming Language
// https://docs.swift.org/swift-book

import MyTransitiveLibrary
import MyCommonLibrary

public struct MyLibrary {
  public static let version = "1.0.0, \(MyTransitiveLibrary.test) - \(MyCommonLibrary.common)"
  public static let view = MyTransitiveLibrary.lottie
}
