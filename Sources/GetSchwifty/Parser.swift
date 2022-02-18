internal struct Parser {
    var rootExpr = RootExpr()

    init(lexemes lexs: LexIterator) throws {
        for l in lexs {
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
