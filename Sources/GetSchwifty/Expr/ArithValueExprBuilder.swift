internal protocol ArithValueExprBuilder: ArithExprBuilder {
    var isStatement: Bool { get }
    func preHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder?
    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder
}

extension ArithValueExprBuilder {
    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        if let pre = try preHandleIdentifierLex(id) {
            return pre
        }

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

    func preHandleIdentifierLex(_ id: IdentifierLex) -> ExprBuilder? {
        return nil
    }
}

internal class IndexingExprBuilder:
        DelimiterLexToListP, PushesStringLexThroughP, PushesNumberLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
    let target: ExprBuilder
    lazy var index: ExprBuilder = VanillaExprBuilder(parent: self)
    let isStatement: Bool
    var range: LexRange!
    let precedence: Precedence = .index

    init(target t: ExprBuilder, isStatement iss: Bool) {
        target = t
        isStatement = iss
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        index = try index.partialPush(lex)
        return self
    }

    func postHandleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder {
        return try pushThrough(i)
    }

    func build() throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self)
        let i: ValueExprP = try index.build(asChildOf: self)
        return IndexingExpr(source: t, operand: i, range: range)
    }
}

internal class FunctionCallExprBuilder:
        ArithValueExprBuilder, PushesDelimiterLexThroughP, PushesNumberLexThroughP, PushesStringLexThroughP, IgnoresWhitespaceLexP, IgnoresCommentLexP {
    var head: ExprBuilder
    lazy var args: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!
    var isStatement: Bool { false }
    let precedence: Precedence = .call

    init(head h: ExprBuilder) {
        head = h
    }

    func build() throws -> ExprP {
        let h: LocationExprP = try head.build(asChildOf: self)
        let a: ValueExprP = try args.build(asChildOf: self)
        return FunctionCallExpr(head: .custom, args: [h, a], range: range)
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        args = try args.partialPush(lex)
        return self
    }

    func preHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder? {
        switch id.literal {
        case String.andIdentifiers where args.consumesAnd:
            return try pushThrough(id)
        default:
            return nil
        }
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        return try pushThrough(id)
    }
}

internal class PopExprBuilder:
        ArithValueExprBuilder, PushesDelimiterLexThroughP, PushesNumberLexThroughP, PushesStringLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
    lazy var source: ExprBuilder = VanillaExprBuilder(parent: self)
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    var expectsTarget: Bool = false
    var range: LexRange!
    let isStatement: Bool = false
    let precedence: Precedence = .call

    func build() throws -> ExprP {
        let s: LocationExprP = try source.build(asChildOf: self)
        if expectsTarget {
            let t: LocationExprP = try target.build(asChildOf: self)
            return VoidCallExpr(head: .pop, target: t, source: s, arg: nil, range: range)
        }
        return FunctionCallExpr(head: .pop, args: [s], range: range)
    }

    @discardableResult
    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        if expectsTarget {
            target = try target.partialPush(lex)
        } else {
            source = try source.partialPush(lex)
        }
        return self
    }

    func postHandleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder {
        switch i.literal {
        case String.intoIdentifiers:
            expectsTarget = true
            return self
        default:
            return try pushThrough(i)
        }
    }
}

internal class StringExprBuilder:
        DelimiterLexToListP, IgnoresCommentLexP, IgnoresWhitespaceLexP, ThrowsNumberLexP {
    let literal: String
    var range: LexRange!
    let isStatement = false
    let precedence: Precedence = .literal

    init(literal s: String) { literal = s }

    func build() -> ExprP {
        return StringExpr(literal: literal, range: range)
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }

    func handleStringLex(_ s: StringLex) throws -> ExprBuilder {
        return self |=> StringExprBuilder(literal: literal + s.literal)
    }
}

internal class NumberExprBuilder:
        DelimiterLexToListP, IgnoresCommentLexP, IgnoresWhitespaceLexP, ThrowsNumberLexP, ThrowsStringLexP {
    let literal: Double
    var range: LexRange!
    let isStatement = false
    let precedence: Precedence = .literal

    func build() -> ExprP {
        return NumberExpr(literal: literal, range: range)
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

internal class BoolExprBuilder:
        DelimiterLexToListP, IgnoresCommentLexP, IgnoresWhitespaceLexP, ThrowsNumberLexP, ThrowsStringLexP {
    let literal: Bool
    var range: LexRange!
    let isStatement = false
    let precedence: Precedence = .literal

    init(literal b: Bool) { literal = b }

    func build() -> ExprP {
        return BoolExpr(literal: literal, range: range)
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }
}

internal class NullExprBuilder:
        DelimiterLexToListP, IgnoresCommentLexP, IgnoresWhitespaceLexP, ThrowsNumberLexP, ThrowsStringLexP {
    var range: LexRange!
    let isStatement = false
    let precedence: Precedence = .literal

    func build() -> ExprP {
        return NullExpr(range: range)
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }
}

internal class MysteriousExprBuilder:
        DelimiterLexToListP, IgnoresCommentLexP, IgnoresWhitespaceLexP, ThrowsNumberLexP, ThrowsStringLexP {
    var range: LexRange!
    let isStatement = false
    let precedence: Precedence = .literal

    func build() -> ExprP {
        return MysteriousExpr(range: range)
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }
}
