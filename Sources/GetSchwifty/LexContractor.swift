fileprivate extension ContractionLex {
    var isIsContraction: Bool { String.isContractionIdentifiers.contains(prettyLiteral!) }

    func toIdentifierLex() -> IdentifierLex {
        if isIsContraction {
            return IdentifierLex(literal: prettyLiteral!, range: range)
        }
        return IdentifierLex(literal: literal, range: range.end-(→range.start))
    }

    func contract(_ lhs: Lex?) -> [Lex] {
        guard let lhs = lhs else {
            return [toIdentifierLex()] }
        guard lhs is IdentifierLex && !isIsContraction else {
            return [lhs, toIdentifierLex()] }
        return [IdentifierLex(literal: lhs.literal + literal, prettyLiteral: lhs.prettyLiteral! + prettyLiteral!, range: range.end-lhs.range.start)]
    }
}

internal struct LexContractor: IteratorProtocol, Sequence {
    var lexemes: LexIterator
    var stack: [Lex] = []

    init(lexemes l: LexIterator) {
        lexemes = l
        guard let first = lexemes.next() else { return }
        stack.append(first)
    }

    mutating func next() -> Lex? {
        while let l = lexemes.next() {
            if let c = l as? ContractionLex {
                stack.append(contentsOf: c.contract(stack.popLast()))
            } else {
                stack.append(l)
                break
            }
        }
        guard let first = stack.first else { return nil }
        return stack.removeFirst()
    }
}
