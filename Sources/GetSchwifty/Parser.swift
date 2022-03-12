internal struct Parser {
    var lexemes: LexContractor
    var currentExprBuilder: ExprBuilder? = VanillaExprBuilder(startPos: LexPos.origin)

    init(input inp: String) {
        let l = LexIterator(input: inp)
        lexemes = LexContractor(lexemes: l)
    }

    mutating func next() throws -> ExprP? {
        while let l = lexemes.next() {
            assert(!(l is ContractionLex), "LexContractor should have filtered these out")

            let partialExpr = try currentExprBuilder!.push(l)

            switch partialExpr {
            case .builder(let b):
                currentExprBuilder = b
            case .expr(let e):
                currentExprBuilder = VanillaExprBuilder(startPos: l.range.end)
                return e
            }
        }

        defer { currentExprBuilder = nil }
        return try currentExprBuilder?.build()
    }
}
