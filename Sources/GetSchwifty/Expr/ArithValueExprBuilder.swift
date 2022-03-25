extension DelimiterLex {
    var isComma: Bool { literal == "," }
}

class IndexingExprBuilder: DelimiterLexToListP,
        PushesStringLexThroughP, PushesNumberLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
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

class FunctionCallExprBuilder: ArithExprBuilder,
        PushesDelimiterLexThroughP, PushesNumberLexThroughP, PushesStringLexThroughP, IgnoresWhitespaceLexP, IgnoresCommentLexP {
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

class ListExprBuilder: ArithExprBuilder,
        PushesNumberLexThroughP, PushesStringLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
    var sources = DLinkedList<ExprBuilder>()
    lazy var currSource: ExprBuilder = VanillaExprBuilder(parent: self)
    var takesAnd: Bool
    var rejectsAnd: Bool
    var isStatement: Bool
    var range: LexRange!
    let precedence: Precedence = .list

    var consumesAnd: Bool { takesAnd }

    init(first s: ExprBuilder, isStatement iss: Bool, takesAnd t: Bool) {
        sources.pushBack(s)
        isStatement = iss
        takesAnd = t
        rejectsAnd = !t
    }

    func build() throws -> ExprP {
        if !currSource.isVanilla {
            sources.pushBack(currSource)
        }
        var members: [ValueExprP] = []
        while let member = sources.popFront() {
            let m: ValueExprP = try member.build(asChildOf: self)
            members.append(m)
        }
        if members.count == 1 {
            return members.first!
        }
        return ListExpr(members: members, range: range)
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        takesAnd = false
        rejectsAnd = false
        currSource = try currSource.partialPush(lex)
        return self
    }

    func preHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder? {
        switch id.literal {
        case String.andIdentifiers where takesAnd:
            takesAnd = false
            rejectsAnd = true
            return self
        case String.andIdentifiers where rejectsAnd:
            throw UnexpectedLexemeError(got: id, parsing: self)
        default:
            return nil
        }
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        return try pushThrough(id)
    }

    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        takesAnd = d.isComma
        rejectsAnd = !takesAnd
        sources.pushBack(currSource)
        currSource = VanillaExprBuilder(parent: self)
        return self
    }
}

class PopExprBuilder: ArithExprBuilder,
        PushesDelimiterLexThroughP, PushesNumberLexThroughP, PushesStringLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
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

class StringExprBuilder: DelimiterLexToListP,
        IgnoresCommentLexP, IgnoresWhitespaceLexP, ThrowsNumberLexP {
    let literal: String
    var range: LexRange!
    let isStatement = false
    let precedence: Precedence = .literal

    init(literal s: String) { literal = s }

    func build() -> ExprP {
        return LiteralExpr(literal: literal, range: range)
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }

    func handleStringLex(_ s: StringLex) throws -> ExprBuilder {
        return self |=> StringExprBuilder(literal: literal + s.literal)
    }
}

class NumberExprBuilder: DelimiterLexToListP,
        IgnoresCommentLexP, IgnoresWhitespaceLexP, ThrowsNumberLexP, ThrowsStringLexP {
    let literal: Double
    var range: LexRange!
    let isStatement = false
    let precedence: Precedence = .literal

    func build() -> ExprP {
        return LiteralExpr(literal: literal, range: range)
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

class LiteralExprBuilder<T>: DelimiterLexToListP,
        IgnoresCommentLexP, IgnoresWhitespaceLexP, ThrowsNumberLexP, ThrowsStringLexP {
    let literal: T
    var range: LexRange!
    let isStatement = false
    let precedence: Precedence = .literal

    init(literal b: T) { literal = b }

    func build() -> ExprP {
        return LiteralExpr(literal: literal, range: range)
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }
}
