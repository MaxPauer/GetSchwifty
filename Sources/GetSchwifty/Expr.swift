fileprivate extension String {
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
    @discardableResult
    mutating func terminate(_ l: Lex) throws -> Expr {
        guard canTerminate else {
            throw UnexpectedEOLError(range: l.range, parsing: self)
        }
        isTerminated = true
        return self
    }
}

internal struct VanillaExpr: Expr {
    var isTerminated = false
    let canTerminate: Bool = true

    func fromIdentifier(_ id: IdentifierLex) -> Expr {
        let word = id.literal
        switch word {
        case String.commonVariableIdentifiers:
            return CommonVariableNameExpr(first: word)
        case String.letAssignIdentifiers:
            return AssignmentExpr(expectingTarget: true)
        case String.putAssignIdentifiers:
            return AssignmentExpr(expectingValue: true)
        case String.listenInputIdentifiers:
            return InputExpr()
        case String.sayOutputIdentifiers:
            return OutputExpr()
        case String.emptyStringIdentifiers:
            return StringExpr(literal: "")
        case String.trueIdentifiers:
            return BoolExpr(literal: true)
        case String.falseIdentifiers:
            return BoolExpr(literal: false)
        case String.nullIdentifiers:
            return NullExpr()
        case String.mysteriousIdentifiers:
            return MysteriousExpr()
        case String.pronounIdentifiers:
            return PronounExpr()

        case \.firstCharIsUpperCase:
            return ProperVariableNameExpr(first: word)
        default:
            return VariableNameExpr(name: word)
        }
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex, is ApostropheLex:
            return self
        case let id as IdentifierLex:
            return fromIdentifier(id)
        case let str as StringLex:
            return StringExpr(literal: str.literal)
        case let num as NumberLex:
            return try NumberExpr(from: num, in: self)
        case is DelimiterLex:
            throw UnexpectedLexemeError(got: lex, parsing: self)
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal protocol PartialLocationExpr: Expr {}

internal protocol LocationExpr: PartialLocationExpr {
    var expectingIsContraction: Bool { get set }
}

extension LocationExpr {
    var canTerminate: Bool { !expectingIsContraction }

    func fromIdentifier(_ id: IdentifierLex) throws -> Expr {
        let word = id.literal
        switch word {
        case String.sayPoeticStringIdentifiers:
            return PoeticStringAssignmentExpr(target: self)
        case String.poeticNumberIdentifiers:
            return PoeticNumberAssignmentExpr(target: self)
        case String.isContractionIdentifiers:
            if expectingIsContraction {
                return PoeticNumberAssignmentExpr(target: self)
            }
            fallthrough
        default:
            throw UnexpectedIdentifierError(got: id, parsing: self, expecting: Set(String.poeticNumberIdentifiers ∪ String.sayPoeticStringIdentifiers))
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
            expectingIsContraction = true
            return self
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal struct PronounExpr: LocationExpr {
    var isTerminated: Bool = false
    var expectingIsContraction: Bool = false
}

internal struct VariableNameExpr: LocationExpr {
    let name: String
    var isTerminated: Bool = false
    var expectingIsContraction: Bool = false

    init(name n: String) {
        name = n.lowercased()
    }
}

internal struct CommonVariableNameExpr: PartialLocationExpr {
    let first: String
    var isTerminated: Bool = false
    let canTerminate: Bool = false

    init(first f: String) {
        first = f
    }

    func fromIdentifier(_ id: IdentifierLex) -> Expr {
        let word = id.literal
        return VariableNameExpr(name: "\(first) \(word)")
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            return self
        case let id as IdentifierLex:
            return fromIdentifier(id)
        case is StringLex, is NumberLex, is DelimiterLex, is ApostropheLex:
            throw UnexpectedLexemeError(got: lex, parsing: self)
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal struct ProperVariableNameExpr: PartialLocationExpr {
    private(set) var words: [String]
    var isTerminated: Bool = false
    let canTerminate: Bool = true

    init(first: String) {
        words = [first]
    }

    func finalize() -> VariableNameExpr {
        VariableNameExpr(name: words.joined(separator: " "))
    }

    func pushToFinalVariable(_ lex: Lex) throws -> Expr {
        var newMe = finalize()
        return try newMe.push(lex)
    }

    mutating func fromIdentifier(_ id: IdentifierLex) throws -> Expr {
        let word = id.literal
        if word.firstCharIsUpperCase {
            words.append(word)
            return self
        } else {
            return try pushToFinalVariable(id)
        }
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            try terminate(lex)
            return finalize()
        case is WhitespaceLex, is CommentLex:
            return self
        case let id as IdentifierLex:
            return try fromIdentifier(id)
        case is DelimiterLex, is ApostropheLex:
            return try pushToFinalVariable(lex)
        case is StringLex, is NumberLex:
            throw UnexpectedLexemeError(got: lex, parsing: self)
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
    var target: Expr = VanillaExpr()
    var value: Expr = VanillaExpr()

    private(set) var expectingTarget: Bool
    private(set) var expectingValue: Bool {
        get {
            !expectingTarget
        } set {
            expectingTarget = !newValue
        }
    }

    var canTerminate: Bool { !(target is VanillaExpr) && !(value is VanillaExpr) }

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

    mutating func fromIdentifier(_ id: IdentifierLex) throws {
        switch id.literal {
        case String.assignBeIdentifiers:
            guard expectingTarget else {
                throw UnexpectedIdentifierError(got: id, parsing: self, expecting: String.assignIntoIdentifiers)
            }
            expectingTarget = false
        case String.assignIntoIdentifiers:
            guard expectingValue else {
                throw UnexpectedIdentifierError(got: id, parsing: self, expecting: String.assignBeIdentifiers)
            }
            expectingValue = false
        default:
            try pushThrough(id)
        }
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            break
        case let id as IdentifierLex:
            try fromIdentifier(id)
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
        target == nil || target is LocationExpr
    }

    mutating func pushThrough(_ lex: Lex) throws {
        guard target != nil else {
            throw UnexpectedLexemeError(got: lex, parsing: self)
        }
        target = try target!.push(lex)
        guard target is VanillaExpr || target is PartialLocationExpr else {
            throw UnexpectedExprError<PartialLocationExpr>(got: target!, range:lex.range, parsing: self)
        }
    }

    mutating func fromIdentifier(_ id: IdentifierLex) throws {
        switch id.literal {
        case String.toIdentifiers:
            target = VanillaExpr()
        default:
            try pushThrough(id)
        }
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            break
        case let id as IdentifierLex:
            try fromIdentifier(id)
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
    var target: Expr = VanillaExpr()

    var canTerminate: Bool {
        !(target is VanillaExpr)
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
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is CommentLex, is WhitespaceLex, is ApostropheLex:
            return self
        case is StringLex, is NumberLex, is DelimiterLex:
            throw LeafExprPushError(got: lex, parsing: self)
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal struct StringExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: String
}

internal struct NumberExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: Float

    init(from l: NumberLex, in e: Expr) throws {
        guard let f = Float(l.literal) else {
            throw UnparsableNumberLexemeError(got: l, parsing: e)
        }
        literal = f
    }
    init(literal f: Float) {
        literal = f
    }
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
    var children: [Expr] = [VanillaExpr()]

    mutating func push(_ lex: Lex) throws -> Expr {
        var lastExpr = children.last!
        if !lastExpr.isTerminated {
            _ = children.popLast()
        } else {
            lastExpr = VanillaExpr()
        }
        children.append(try lastExpr.push(lex))
        return self
    }
}
