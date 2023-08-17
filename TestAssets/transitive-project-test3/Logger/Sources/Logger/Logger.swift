public struct Logger {
    public private(set) var text = "Hello, World!"

    public init() {
    }
    
    public func log(msg:String) {
        print("Log: \(msg)")
    }
}
