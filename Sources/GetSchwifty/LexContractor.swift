fileprivate extension ContractionLex {
    var isIsContraction: Bool { String.isContractionIdentifiers.contains(prettyLiteral!) }

    func toSimpleLex() -> Lex {
        if isIsContraction {
            return IdentifierLex(literal: prettyLiteral!, range: range)
        } else if literal.isEmpty {
            return WhitespaceLex(literal: prettyLiteral!, range: range)
        }
        return IdentifierLex(literal: literal, prettyLiteral: prettyLiteral!, range: range.end-(→range.start))
    }

    func contract(_ lhs: Lex?) -> [Lex] {
        guard let lhs = lhs else {
            return [toSimpleLex()] }
        guard lhs is IdentifierLex && !isIsContraction else {
            return [lhs, toSimpleLex()] }
        return [IdentifierLex(literal: lhs.literal + literal, prettyLiteral: lhs.prettyLiteral! + prettyLiteral!, range: range.end-lhs.range.start)]
    }
}

struct LexContractor: IteratorProtocol, Sequence {
    var lexemes: LexIterator
    var ll = DLinkedList<Lex>()

    init(lexemes l: LexIterator) {
        lexemes = l
        guard let first = lexemes.next() else { return }
        ll.pushBack(first)
    }

    mutating func next() -> Lex? {
        while let l = lexemes.next() {
            if let c = l as? ContractionLex {
                c.contract(ll.popBack()).forEach{ ll.pushBack($0) }
            } else {
                ll.pushBack(l)
                break
            }
        }
        return ll.popFront()
    }
}
