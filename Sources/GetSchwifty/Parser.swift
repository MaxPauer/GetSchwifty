internal struct Parser {
    var rootExpr = RootExpr()

    init(lexemes: [Lex]) throws {
        var lexs = Fifo<[Lex]>(lexemes)

        while let l = lexs.pop() {
            do {
                _ = try rootExpr.push(l)
            } catch let err as ParserError {
                throw err
            } catch {
                assertionFailure("unexpected Error")
            }
        }
    }
}
