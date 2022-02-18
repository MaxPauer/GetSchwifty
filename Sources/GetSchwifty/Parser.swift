internal struct Parser {
    var lexemes: LexIterator
    var currentExpr: Expr?

    mutating func flushCurrentExpr() -> Expr? {
        defer { currentExpr = nil }
        return currentExpr
    }

    mutating func next() throws -> Expr? {
        while let l = lexemes.next() {
            currentExpr = currentExpr ?? VanillaExpr()

            do {
                currentExpr = try currentExpr!.push(l)
            } catch let err as ParserError {
                throw err
            } catch {
                assertionFailure("unexpected Error")
            }

            if currentExpr!.isTerminated {
                return flushCurrentExpr()
            }
        }

        return flushCurrentExpr()
    }
}
