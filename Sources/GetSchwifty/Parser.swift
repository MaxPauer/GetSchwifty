internal struct Parser {
    var rootExpr = RootExpr()

    init(lexemes: [Lex]) throws {
        var lexs = Fifo<[Lex]>(lexemes)

        while let l = lexs.pop() {
            do {
                _ = try rootExpr.push(l)
            } catch let err as PartialParserError {
                throw ParserError(onLine: l.range.start.line, partialErr: err)
            } catch {
                assertionFailure("unexpected Error")
            }
        }
    }
}
