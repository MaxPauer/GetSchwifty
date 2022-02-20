internal struct Parser {
    var lexemes: LexContractor
    var currentExprBuilder: ExprBuilder = VanillaExprBuilder(parent: nil)

    init(input inp: String) {
        let l = LexIterator(input: inp)
        lexemes = LexContractor(lexemes: l)
    }

    mutating func next() throws -> ExprP? {
        while let l = lexemes.next() {
            assert(!(l is ContractionLex), "LexContractor should have filtered these out")

            var partialExpr: PartialExpr!
            do {
                partialExpr = try currentExprBuilder.push(l)
            } catch let err as ParserError {
                throw err
            } catch {
                assertionFailure("unexpected Error")
            }

            switch partialExpr! {
            case .builder(let b):
                currentExprBuilder = b
            case .expr(let e):
                currentExprBuilder = VanillaExprBuilder(parent: nil)
                return e
            }
        }

        return try currentExprBuilder.build(inRange: LexPos(line: 0, char: 0)-LexPos(line: 0, char: 0))
    }
}
