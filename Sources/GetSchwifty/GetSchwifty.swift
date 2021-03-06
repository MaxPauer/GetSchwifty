public struct Rockstar {
    private init() {}

    internal struct Null: Equatable {}
    public struct Mysterious: Equatable {}

    static internal let null = Null()
    static public let mysterious = Mysterious()
}

public typealias Rockin = () throws -> Any?
public typealias Rockout = (Any?) throws -> Void

public struct GetSchwifty {
    private var exprCache = DLinkedList<ExprP>()
    private var rockin: Rockin
    private var rockout: Rockout
    public var maxLoopIterations: UInt?

    init(input inp: String, rockin i: Rockin? = nil, rockout o: Rockout? = nil) throws {
        var parser = Parser(input: inp)

        while let e = try parser.next() {
            exprCache.pushBack(e)
        }

        rockin = i ?? { Rockstar.null }
        rockout = o ?? {_ in}
    }

    func run(rockin i: Rockin? = nil, rockout o: Rockout? = nil) throws {
        let ctx = MainEvalContext(
            input: exprCache.walkFrontToBack,
            debuggingSettings: DebuggingSettings(maxLoopIterations: maxLoopIterations),
            rockin: i ?? rockin,
            rockout: o ?? rockout)
        try ctx.run()
    }
}
