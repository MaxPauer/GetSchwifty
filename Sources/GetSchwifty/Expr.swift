fileprivate extension String {
    var isCommonVariableIdentifier: Bool {
        let l = self.lowercased()
        return l == "a" || l == "an" || l == "the" || l == "my" || l == "your" || l == "our"
    }
    var firstCharIsUpperCase: Bool {
        return self.first!.isUppercase
    }
}

internal protocol Expr {
    var isTerminated: Bool { get set }
    var canTerminate: Bool { get }
    mutating func push(_ lex: Lex) throws -> Expr
}

extension Expr {
    mutating func terminate(_ l: Lex) throws -> Expr {
        guard canTerminate else {
            throw UnexpectedEOLError(got: l, parsing: self)
        }
        isTerminated = true
        return self
    }
}

internal struct VirginExpr: Expr {
    var isTerminated = false
    let canTerminate: Bool = true

    func fromIdentifier(_ id: IdentifierLex) -> Expr {
        let word = id.literal.lowercased()
        switch word {
        case \.isCommonVariableIdentifier:
            return CommonVariableNameExpr(first: word)
        case "let":
            return AssignmentExpr(expectingTarget: true)
        case "put":
            return AssignmentExpr(expectingValue: true)
        case "listen":
            return InputExpr()
        case "say", "shout", "whisper", "scream":
            return OutputExpr()
        case "empty", "silent", "silence":
            return StringExpr(literal: "")
        case "true", "right", "yes", "ok":
            return BoolExpr(literal: true)
        case "false", "wrong", "no", "lies":
            return BoolExpr(literal: false)
        case "null", "nothing", "nobody", "nowhere", "gone":
            return NullExpr()
        case "mysterious":
            return MysteriousExpr()
        default:
            //TODO: replace with simple variable
            return self
        }
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            return self
        case let id as IdentifierLex:
            return fromIdentifier(id)
        case let str as StringLex:
            return StringExpr(literal: str.literal)
        case let num as NumberLex:
            return NumberExpr(literal: num.value)
        case is ApostropheLex, is DelimiterLex:
            throw UnexpectedLexemeError(got: lex, parsing: self)
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal struct CommonVariableNameExpr: Expr {
    let first: String
    var second: String?
    var isTerminated: Bool = false
    var canTerminate: Bool { second != nil }

    var name: String { "\(first) \(second!)" }

    mutating func fromIdentifier(_ id: IdentifierLex) throws -> Expr {
        let word = id.literal.lowercased()
        if second == nil {
            second = word
            return self
        }

        switch word {
        case "is", "are", "was", "were":
            return PoeticNumberAssignmentExpr(target: self)
        case "say", "says", "said":
            return PoeticStringAssignmentExpr(target: self)
        default:
            throw UnexpectedIdentifierError(got: id, parsing: self, expecting: Set(["is", "are", "was", "were", "say", "says", "said"]))
        }
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            return self
        case let id as IdentifierLex:
            return try fromIdentifier(id)
        case is StringLex, is NumberLex, is DelimiterLex:
            throw UnexpectedLexemeError(got: lex, parsing: self)
        case is ApostropheLex:
            throw NotImplementedError(got: lex)
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal protocol AnyAssignmentExpr: Expr {
    associatedtype ValueType
    var target: Expr { get }
    var value: ValueType { get }
}

internal struct PoeticNumberAssignmentExpr: AnyAssignmentExpr {
    var isTerminated: Bool = false
    var target: Expr
    private var _value: Int = 0
    var value: NumberExpr?

    init(target t: Expr) {
        target = t
    }

    var canTerminate: Bool { _value != 0 }

    mutating func addPoeticNumber(fromString s: String) {
        _value *= 10
        _value = _value + (s.count % 10)
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is WhitespaceLex, is CommentLex:
            break
        case is NewlineLex:
            value = NumberExpr(literal: Float(_value))
            return try terminate(lex)
        case let id as IdentifierLex:
            addPoeticNumber(fromString: id.literal)
        case is StringLex, is ApostropheLex, is DelimiterLex, is NumberLex:
            throw UnexpectedLexemeError(got: lex, parsing: self)
        default:
            assertionFailure("unhandled lexeme")
        }
        return self
    }
}

internal struct PoeticStringAssignmentExpr: AnyAssignmentExpr {
    var isTerminated: Bool = false
    var target: Expr
    private var _value: String = ""
    var value: StringExpr?

    init(target t: Expr) {
        target = t
    }

    var canTerminate: Bool { !_value.isEmpty }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            value = StringExpr(literal: _value)
            return try terminate(lex)
        case is IdentifierLex, is ApostropheLex, is DelimiterLex, is NumberLex:
            _value += lex.literal
        case is WhitespaceLex:
            let hasContent = canTerminate
            if hasContent {
                _value += lex.literal
            }
        case let comm as CommentLex:
            _value += "(\(comm.literal))"
        case let str as StringLex:
            _value += "\"\(str.literal)\""
        default:
            assertionFailure("unhandled lexeme")
        }

        return self
    }
}

internal struct AssignmentExpr: AnyAssignmentExpr {
    var isTerminated: Bool = false
    var target: Expr = VirginExpr()
    var value: Expr = VirginExpr()

    private(set) var expectingTarget: Bool
    private(set) var expectingValue: Bool {
        get {
            !expectingTarget
        } set {
            expectingTarget = !newValue
        }
    }

    var canTerminate: Bool { !(target is VirginExpr) && !(value is VirginExpr) }

    init(expectingTarget et: Bool) {
        expectingTarget = et
    }
    init(expectingValue ev: Bool) {
        self.init(expectingTarget: !ev)
    }

    mutating func pushThrough(_ lex: Lex) throws {
        if expectingTarget {
            target = try target.push(lex)
        } else {
            value = try value.push(lex)
        }
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            break
        case let id as IdentifierLex:
            let lit = id.literal.lowercased()
            if lit == "be" {
                guard expectingTarget else {
                    throw UnexpectedIdentifierError(got: id, parsing: self, expecting: Set(["in", "into"]))
                }
                expectingTarget = false
                break
            } else if lit == "in" || lit == "into" {
                guard expectingValue else {
                    throw UnexpectedIdentifierError(got: id, parsing: self, expecting: Set(["be"]))
                }
                expectingValue = false
                break
            }
            fallthrough
        case is StringLex, is ApostropheLex, is DelimiterLex, is NumberLex:
            try pushThrough(lex)
        default:
            assertionFailure("unhandled lexeme")
        }

        return self
    }
}

internal struct InputExpr: Expr {
    var isTerminated: Bool = false
    var target: Expr?

    var canTerminate: Bool {
        target == nil || !(target is VirginExpr)
    }

    mutating func pushThrough(_ lex: Lex) throws {
        guard target != nil else {
            throw UnexpectedLexemeError(got: lex, parsing: self)
        }
        target = try target!.push(lex)
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            break
        case let id as IdentifierLex:
            if id.literal.lowercased() == "to" {
                target = VirginExpr()
            } else {
                try pushThrough(lex)
            }
        case is StringLex, is ApostropheLex, is DelimiterLex, is NumberLex:
            try pushThrough(lex)
        default:
            assertionFailure("unhandled lexeme")
        }

        return self
    }
}

internal struct OutputExpr: Expr {
    var isTerminated: Bool = false
    var target: Expr = VirginExpr()

    var canTerminate: Bool {
        !(target is VirginExpr)
    }

    mutating func pushThrough(_ lex: Lex) throws {
        target = try target.push(lex)
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            break
        case is IdentifierLex, is StringLex, is ApostropheLex, is DelimiterLex, is NumberLex:
            try pushThrough(lex)
        default:
            assertionFailure("unhandled lexeme")
        }

        return self
    }
}

internal protocol LeafExpr: Expr {
    associatedtype LiteralType
    var literal: LiteralType { get }
}

extension LeafExpr {
    var canTerminate: Bool { true }
    mutating func push(_ lex: Lex) throws -> Expr {
        guard lex is NewlineLex else {
            throw LeafExprPushError(got: lex, leafExpr: self)
        }
        return try terminate(lex)
    }
}

internal struct StringExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: String
}

internal struct NumberExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: Float
}

internal struct BoolExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: Bool
}

internal struct NullExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: Int? = nil
}

internal struct MysteriousExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: Int? = nil
}

internal struct RootExpr: Expr {
    var isTerminated: Bool = false
    let canTerminate: Bool = false
    var children: [Expr] = [VirginExpr()]

    mutating func push(_ lex: Lex) throws -> Expr {
        var lastExpr = children.last!
        if !lastExpr.isTerminated {
            _ = children.popLast()
        } else {
            lastExpr = VirginExpr()
        }
        children.append(try lastExpr.push(lex))
        return self
    }
}
