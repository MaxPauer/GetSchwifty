fileprivate extension String {
    var firstCharIsUpperCase: Bool {
        return self.first!.isUppercase
    }
}

internal protocol Expr: CustomStringConvertible {
    var isTerminated: Bool { get set }
    var canTerminate: Bool { get }
    var prettyName: String { get }
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

    var description: String {
        "[\(prettyName) Expression]"
    }
}

internal struct VanillaExpr: Expr {
    var isTerminated = false
    let canTerminate: Bool = true
    let prettyName: String = "Vanilla"

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

internal protocol LocationExpr: Expr {}

internal protocol FinalizedLocationExpr: LocationExpr {
    var expectingIsContraction: Bool { get set }
}

extension FinalizedLocationExpr {
    var canTerminate: Bool { !expectingIsContraction }

    func fromIdentifier(_ id: IdentifierLex) throws -> Expr {
        let word = id.literal
        switch word {
        case String.sayPoeticStringIdentifiers:
            return PoeticStringAssignmentExpr(target: self)
        case String.poeticNumberIdentifiers:
            return PoeticNumberAssignmentExpr(target: self)
        case String.indexingIdentifiers:
            return IndexingLocationExpr(target: self)
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

internal struct PronounExpr: FinalizedLocationExpr {
    var isTerminated: Bool = false
    var expectingIsContraction: Bool = false
    let prettyName: String = "Pronoun"
}

internal struct VariableNameExpr: FinalizedLocationExpr {
    let name: String
    var isTerminated: Bool = false
    var expectingIsContraction: Bool = false
    var prettyName: String { "Variable Name (=\(name))" }

    init(name n: String) {
        name = n.lowercased()
    }
}

internal struct IndexingLocationExpr: LocationExpr {
    let target: LocationExpr
    var index: Expr = VanillaExpr()
    var isTerminated: Bool = false
    var prettyName: String { "Indexing (=\(target)[\(index)])" }

    var canTerminate: Bool { !(index is VanillaExpr) }

    mutating func pushThrough(_ lex: Lex) throws {
        index = try index.push(lex)
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            try pushThrough(lex)
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            return self
        case is IdentifierLex, is StringLex, is NumberLex, is DelimiterLex, is ApostropheLex:
            try pushThrough(lex)
            return self
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal struct CommonVariableNameExpr: LocationExpr {
    let first: String
    var isTerminated: Bool = false
    let canTerminate: Bool = false
    var prettyName: String { "Variable Name (unfinished=\(first) …)" }

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

internal struct ProperVariableNameExpr: LocationExpr {
    private(set) var words: [String]
    var isTerminated: Bool = false
    let canTerminate: Bool = true
    var prettyName: String { "Variable Name (unfinished=\(name) …)" }

    init(first: String) {
        words = [first]
    }

    private var name: String { words.joined(separator: " ") }

    func finalize() -> VariableNameExpr {
        VariableNameExpr(name: name)
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
    private var digits: [Int] = []
    private var continueDigit = false
    var value: NumberExpr?
    let prettyName: String = "Poetic Number Assignment"

    init(target t: Expr) {
        // TODO check is LocationExpr
        target = t
    }

    var canTerminate: Bool { digits.count > 0 }

    mutating func addPoeticNumber(fromString s: String) {
        var newDigit: Int!
        if continueDigit {
            newDigit = ((digits.popLast() ?? 0) + s.count) % 10
            continueDigit = false
        } else {
            newDigit = s.count % 10
        }
        digits.append(newDigit)
    }

    func calcValue() -> Double {
        var v = 0
        for digit in digits {
            v *= 10
            v += digit
        }
        return Double(v)
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is WhitespaceLex, is CommentLex:
            break
        case is NewlineLex:
            value = NumberExpr(literal: calcValue())
            return try terminate(lex)
        case let id as IdentifierLex:
            addPoeticNumber(fromString: id.literal)
        case is ApostropheLex:
            continueDigit = true
        break
        case is StringLex, is DelimiterLex, is NumberLex:
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
    let prettyName: String = "Poetic String Assignment"

    init(target t: Expr) {
        // TODO check is LocationExpr
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
    let prettyName: String = "Assignment"

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
            try pushThrough(lex)
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
    let prettyName: String = "Input"

    var canTerminate: Bool {
        target == nil || !(target is VanillaExpr)
    }

    mutating func pushThrough(_ lex: Lex) throws {
        guard target != nil else {
            throw UnexpectedLexemeError(got: lex, parsing: self)
        }
        target = try target!.push(lex)
        guard target is VanillaExpr || target is LocationExpr else {
            throw UnexpectedExprError<LocationExpr>(got: target!, range:lex.range, parsing: self)
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
            if target != nil {
                try pushThrough(lex)
            }
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
    let prettyName: String = "Output"

    var canTerminate: Bool {
        !(target is VanillaExpr)
    }

    mutating func pushThrough(_ lex: Lex) throws {
        target = try target.push(lex)
    }

    mutating func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            try pushThrough(lex)
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
    var prettyName: String { "String (=\"\(literal)\")" }
}

internal struct NumberExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: Double
    var prettyName: String { "Numberic Value (=\"\(literal)\")" }

    init(from l: NumberLex, in e: Expr) throws {
        guard let f = Double(l.literal) else {
            throw UnparsableNumberLexemeError(got: l, parsing: e)
        }
        literal = f
    }
    init(literal f: Double) {
        literal = f
    }
}

internal struct BoolExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: Bool
    var prettyName: String { "Boolean Value (=\"\(literal)\")" }
}

internal struct NullExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: Int? = nil
    let prettyName: String = "Null Value"
}

internal struct MysteriousExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: Int? = nil
    let prettyName: String = "Mysterious Value"
}

internal struct RootExpr: Expr {
    var isTerminated: Bool = false
    let canTerminate: Bool = false
    var children: [Expr] = [VanillaExpr()]
    let prettyName: String = "Root"

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
