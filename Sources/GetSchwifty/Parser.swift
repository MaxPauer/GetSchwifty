internal struct Parser {
    var lexemes: LexContractor
    var currentExpr: Expr?

    init(lexemes l: LexIterator) {
        lexemes = LexContractor(lexemes: l)
    }

    mutating func flushCurrentExpr() -> Expr? {
        defer { currentExpr = nil }
        return currentExpr
    }

    mutating func next() throws -> Expr? {
        while let l = lexemes.next() {
            assert(!(l is ContractionLex), "LexContractor should have filtered these out")
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
