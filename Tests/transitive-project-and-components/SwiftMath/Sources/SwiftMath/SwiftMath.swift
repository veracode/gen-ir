// The Swift Programming Language
// https://docs.swift.org/swift-book

enum OperationError:Error {
    case DivideByZero
}

public func mult(lhs:Int, rhs:Int) -> Int {
    return lhs * rhs 
}

public func div(lhs: Int, rhs: Int) throws -> Int {
    guard rhs != 0 else {
        throw OperationError.DivideByZero
    }

    return lhs / rhs 
}

public func add( lhs: Int, rhs: Int) -> Int {
    return lhs + rhs 
}

public func sub( lhs: Int, rhs: Int) -> Int {
    return lhs - rhs
}
