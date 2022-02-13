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
    var isTerminated: Bool { get }
    mutating func push(_ lex: Lex) throws -> Expr
}

internal struct VirginExpr: Expr {
    let isTerminated = false

    func fromIdentifier(_ id: IdentifierLex) -> Expr {
        let word = id.literal.lowercased()
        switch word {
        case \.isCommonVariableIdentifier:
            return CommonVariableNameExpr(first: word)
        case "let":
            return AssignmentExpr(expectingTarget: true)
        case "listen":
            return InputExpr()
        default:
            //TODO: replace with simple variable
            return self
        }
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is WhitespaceLex, is NewlineLex, is CommentLex:
            return self
        case let id as IdentifierLex:
            return fromIdentifier(id)
        case let str as StringLex:
            return StringExpr(literal: str.literal)
        case let num as NumberLex:
            return NumberExpr(literal: num.value)
        default:
            throw NotImplementedError()
        }
    }
}

internal struct CommonVariableNameExpr: Expr {
    let first: String
    var second: String?
    var isTerminated: Bool = false

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
            throw NotImplementedError() // more like: not an acceptable Idenfifier
        }
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            isTerminated = true
            return self
        case is WhitespaceLex, is CommentLex:
            return self
        case let id as IdentifierLex:
            return try fromIdentifier(id)
        case is NewlineLex:
            throw UnexpectedLexemeError(got: lex, expected: IdentifierLex.self) // WS also ok...
        default:
            throw NotImplementedError()
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

    mutating func addPoeticNumber(fromString s: String) {
        _value *= 10
        _value = _value + (s.count % 10)
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is WhitespaceLex, is CommentLex:
            break
        case is NewlineLex:
            guard _value != 0 else {
                throw UnexpectedLexemeError(got: lex, expected: IdentifierLex.self) // WS also OK
            }
            value = NumberExpr(literal: Float(_value))
            isTerminated = true
        case let id as IdentifierLex:
            addPoeticNumber(fromString: id.literal)
        default:
            throw UnexpectedLexemeError(got: lex, expected: IdentifierLex.self) // WS also acceptable
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

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            guard !_value.isEmpty else {
                throw UnexpectedLexemeError(got: lex, expected: IdentifierLex.self) // WS and others also OK
            }
            value = StringExpr(literal: _value)
            isTerminated = true
        case is IdentifierLex, is ApostropheLex, is DelimiterLex, is NumberLex:
            _value += lex.literal
        case is WhitespaceLex:
            if !_value.isEmpty {
                _value += lex.literal
            }
        case is CommentLex:
            break // TODO: nop or interpret as (bla)?
        case let str as StringLex:
            _value += "\"\(str.literal)\""
        default:
            assertionFailure("unexpected lexeme")
        }

        return self
    }
}

internal struct AssignmentExpr: AnyAssignmentExpr {
    var isTerminated: Bool = false
    var target: Expr = VirginExpr()
    var value: Expr = VirginExpr()

    private(set) var expectingTarget: Bool
    var expectingValue: Bool { !expectingTarget }

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
            guard !(target is VirginExpr) && !(value is VirginExpr) else {
                throw UnexpectedLexemeError(got: lex, expected: IdentifierLex.self) // TODO: actually we expect whatever
            }
            isTerminated = true
        case is WhitespaceLex, is CommentLex:
            break
        case let id as IdentifierLex:
            if id.literal.lowercased() == "be" {
                guard expectingTarget else {
                    throw UnexpectedLexemeError(got: lex, expected: IdentifierLex.self) // TODO: actually we just did not expect this one
                }
                expectingTarget = false
            } else {
                try pushThrough(lex)
            }
        default:
            try pushThrough(lex)
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
            throw UnexpectedLexemeError(got: lex, expected: IdentifierLex.self) // TODO: actually we expect whatever
        }
        target = try target!.push(lex)
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            guard canTerminate else {
                throw UnexpectedLexemeError(got: lex, expected: IdentifierLex.self) // TODO: actually we expect whatever
            }
            isTerminated = true
        case is WhitespaceLex, is CommentLex:
            break
        case let id as IdentifierLex:
            if id.literal.lowercased() == "to" {
                target = VirginExpr()
            } else {
                try pushThrough(lex)
            }
        default:
            try pushThrough(lex)
        }

        return self
    }
}

internal protocol LeafExpr: Expr {
    associatedtype LiteralType
    var literal: LiteralType { get }
}

extension LeafExpr {
    mutating func push(_ lex: Lex) throws -> Expr {
        throw UnexpectedLexemeError(got: lex, expected: IdentifierLex.self) // TODO oh boy...
    }
}

internal struct StringExpr: LeafExpr {
    let isTerminated: Bool = false
    let literal: String
}

internal struct NumberExpr: LeafExpr {
    let isTerminated: Bool = false
    let literal: Float
}

internal struct RootExpr: Expr {
    let isTerminated: Bool = false
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
