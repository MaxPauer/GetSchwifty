fileprivate extension Character {
    var isDot: Bool { self == "." }
}

fileprivate extension String {
    var firstCharIsDot: Bool {
        return self.first?.isDot ?? false
    }
}

fileprivate extension IdentifierLex {
    var isIsContraction: Bool { String.isContractionIdentifiers.contains(literal) }
    var poeticNumeralValue: Int {
        let n = isIsContraction ?
            literal.count - 1 : literal.count
        return n % 10
    }
}


internal class PoeticConstantExprBuilder: SingleExprBuilder {
    lazy private var constant: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    func build() throws -> ExprP {
        let v: ValueExprP = try constant.build(asChildOf: self)
        return v
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        guard constant is VanillaExprBuilder else { return self }
        constant = try constant.partialPush(id)
        return self
    }

    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        return self
    }

    func handleStringLex(_ s: StringLex) throws -> ExprBuilder {
        return self
    }

    func handleNumberLex(_ n: NumberLex) throws -> ExprBuilder {
        return self
    }
}

internal class PoeticNumberExprBuilder: SingleExprBuilder {
    private var value = 0.0
    private var divider: Double = 1.0
    private var digit: Int? = nil
    var range: LexRange!

    func addToPoeticDigit(from id: IdentifierLex) {
        digit = (digit ?? 0) + id.poeticNumeralValue
    }

    @discardableResult
    func pushPoeticDigit() -> ExprBuilder {
        if let n = digit {
            if divider == 1.0 {
                value *= 10
                value += Double(n % 10)
            } else {
                value += Double(n) * divider
                divider *= 0.1
            }
            digit = nil
        }
        return self
    }

    func build() throws -> ExprP {
        pushPoeticDigit()
        return value == 0 ? NopExpr() : NumberExpr(literal: Double(value))
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        if value == 0 {
            switch id.literal {
            case String.constantIdentifiers:
                var c: ExprBuilder = self |=> PoeticConstantExprBuilder()
                c = try c.partialPush(id)
                return c
            default: break
            }
        }
        addToPoeticDigit(from: id)
        return self
    }

    func handleCommentLex(_ c: CommentLex) throws -> ExprBuilder {
        return pushPoeticDigit()
    }

    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        return pushPoeticDigit()
    }

    func handleWhitespaceLex(_ w: WhitespaceLex) throws -> ExprBuilder {
        pushPoeticDigit()
        if divider == 1.0 && w.literal.firstCharIsDot {
            divider = 0.1
        }
        return self
    }
}

internal class PoeticNumberishAssignmentExprBuilder: SingleExprBuilder, PushesDelimiterThrough, PushesIdentifierThrough {
    var target: ExprBuilder
    lazy var source: ExprBuilder = self |=> PoeticNumberExprBuilder()
    var range: LexRange!

    init(target t: ExprBuilder) {
        target = t
    }

    func build() throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self)
        let s: ValueExprP = try source.build(asChildOf: self)
        return VoidCallExpr(head: .assign, target: t, source: s, arg: nil)
    }

    @discardableResult
    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        source = try source.partialPush(lex)
        return self
    }

    func handleCommentLex(_ c: CommentLex) throws -> ExprBuilder {
        return try pushThrough(c)
    }

    func handleWhitespaceLex(_ w: WhitespaceLex) throws -> ExprBuilder {
        return try pushThrough(w)
    }
}

internal class PoeticStringAssignmentExprBuilder:
        SingleExprBuilder, PushesDelimiterThrough, PushesIdentifierThrough, PushesNumberThrough, PushesStringThrough {
    var target: ExprBuilder
    lazy private var value: String = ""
    private var whitespaceSeen = false
    var range: LexRange!

    init(target t: ExprBuilder) {
        target = t
    }

    func build() throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self)
        return VoidCallExpr(head: .assign, target: t, source: StringExpr(literal: value), arg: nil)
    }

    func append(_ s: String) {
        value += s
    }

    @discardableResult
    func pushThrough(_ lex: Lex) -> ExprBuilder {
        append(lex.prettyLiteral ?? lex.literal)
        return self
    }

    func handleCommentLex(_ c: CommentLex) throws -> ExprBuilder {
        return pushThrough(c)
    }

    func handleWhitespaceLex(_ w: WhitespaceLex) throws -> ExprBuilder {
        let ws = w.literal
        if !whitespaceSeen {
            whitespaceSeen = true
            let st = ws.index(ws.startIndex, offsetBy: 1)
            append(String(ws[st..<ws.endIndex]))
        } else {
            append(ws)
        }
        return self
    }
}
