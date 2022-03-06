public struct Rockstar {
    private init() {}

    public struct Null: Equatable {}
    public struct Mysterious: Equatable {}

    static public let null = Null()
    static public let mysterious = Mysterious()
}

public func getSchwifty(_ in: String) -> String {
    return ""
}
