fileprivate extension DelimiterLex {
    var isComma: Bool { literal == "," }
}

internal protocol ArithValueExprBuilder: SingleExprBuilder {
    var isStatement: Bool { get }
    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder
}

extension ArithValueExprBuilder {
    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        switch id.literal {
        case String.additionIdentifiers:
            return BiArithExprBuilder(op: .add, lhs: self)
        case String.subtractionIdentifiers:
            return BiArithExprBuilder(op: .sub, lhs: self)
        case String.multiplicationIdentifiers:
            return BiArithExprBuilder(op: .mul, lhs: self)
        case String.divisionIdentifiers:
            return BiArithExprBuilder(op: .div, lhs: self)
        case String.andIdentifiers:
            return BiArithExprBuilder(op: .and, lhs: self)
        case String.orIdentifiers:
            return BiArithExprBuilder(op: .orr, lhs: self)
        case String.norIdentifiers:
            return BiArithExprBuilder(op: .nor, lhs: self)
        case String.isntIdentifiers:
            return BiArithExprBuilder(op: .neq, lhs: self)
        case String.isIdentifiers:
            if isStatement {
                return PoeticNumberishAssignmentExprBuilder(target: self)
            }
            return BiArithExprBuilder(op: .eq, lhs: self)

        default:
            return try postHandleIdentifierLex(id)
        }
    }

    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        return ListExprBuilder(first: self, isStatement: isStatement)
    }
}

internal class ListExprBuilder: SingleExprBuilder, PushesNumberThrough, PushesStringThrough {
    var sources = DLinkedList<ExprBuilder>()
    lazy var currSource: ExprBuilder = VanillaExprBuilder(parent: self)
    var takesAnd: Bool
    var isStatement: Bool
    var range: LexRange!

    init(first s: ExprBuilder, isStatement iss: Bool) {
        sources.pushBack(s)
        isStatement = iss
        takesAnd = true
    }

    func build() throws -> ExprP {
        sources.pushBack(currSource)
        var members: [ValueExprP] = []
        while let member = sources.popFront() {
            let m: ValueExprP = try member.build(asChildOf: self)
            members.append(m)
        }
        return ListExpr(members: members)
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        takesAnd = false
        currSource = try currSource.partialPush(lex)
        return self
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        switch id.literal {
        case String.andIdentifiers where takesAnd:
            takesAnd = false
            return self
        default:
            return try pushThrough(id)
        }
    }

    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        takesAnd = d.isComma
        sources.pushBack(currSource)
        currSource = VanillaExprBuilder(parent: self)
        return self
    }
}

internal class StringExprBuilder: ArithValueExprBuilder {
    let literal: String
    var range: LexRange!
    let isStatement = false

    init(literal s: String) { literal = s }

    func build() -> ExprP {
        return StringExpr(literal: literal)
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        switch id.literal {
        case String.indexingIdentifiers:
            return IndexingLocationExprBuilder(target: self, isStatement: isStatement)
        default:
            throw UnexpectedLexemeError(got: id, parsing: self)
        }
    }

    func handleStringLex(_ s: StringLex) throws -> ExprBuilder {
        return self |=> StringExprBuilder(literal: literal + s.literal)
    }
}

internal class NumberExprBuilder: ArithValueExprBuilder {
    let literal: Double
    var range: LexRange!
    let isStatement = false

    func build() -> ExprP {
        return NumberExpr(literal: literal)
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }

    init(from l: NumberLex, in e: ExprBuilder) throws {
        guard let f = Double(l.literal) else {
            throw UnparsableNumberLexemeError(got: l, parsing: e)
        }
        literal = f
    }

    init(literal f: Double) {
        literal = f
    }
}

internal class BoolExprBuilder: ArithValueExprBuilder {
    let literal: Bool
    var range: LexRange!
    let isStatement = false

    init(literal b: Bool) { literal = b }

    func build() -> ExprP {
        return BoolExpr(literal: literal)
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }
}

internal class NullExprBuilder: ArithValueExprBuilder {
    var range: LexRange!
    let isStatement = false

    func build() -> ExprP {
        return NullExpr()
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }
}

internal class MysteriousExprBuilder: ArithValueExprBuilder {
    var range: LexRange!
    let isStatement = false

    func build() -> ExprP {
        return MysteriousExpr()
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }
}
