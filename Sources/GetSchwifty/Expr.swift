fileprivate extension String {
    var firstCharIsUpperCase: Bool {
        return self.first?.isUppercase ?? false
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

internal protocol Expr: AnyObject, CustomStringConvertible {
    var isTerminated: Bool { get set }
    var canTerminate: Bool { get }
    var prettyName: String { get }
    func push(_ lex: Lex) throws -> Expr
}

extension Expr {
    @discardableResult
    func terminate(_ l: Lex) throws -> Expr {
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

internal class VanillaExpr: Expr {
    var isTerminated = false
    let canTerminate: Bool = true
    let prettyName: String = "Vanilla"
    let parent: Expr?

    init(parent p: Expr?) {
        parent = p
    }

    private var bestErrorLocation: Expr { parent ?? self }

    func fromIdentifier(_ id: IdentifierLex) -> Expr {
        let word = id.literal
        switch word {
        case \.isEmpty:
            return self
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

    func push(_ lex: Lex) throws -> Expr {
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
            return try NumberExpr(from: num, in: bestErrorLocation)
        case is DelimiterLex:
            throw UnexpectedLexemeError(got: lex, parsing: bestErrorLocation)
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal protocol LocationExpr: Expr {}

internal protocol FinalizedLocationExpr: LocationExpr {}

extension FinalizedLocationExpr {
    var canTerminate: Bool { true }

    func fromIdentifier(_ id: IdentifierLex) throws -> Expr {
        let word = id.literal
        switch word {
        case String.sayPoeticStringIdentifiers:
            return PoeticStringAssignmentExpr(target: self)
        case String.poeticNumberIdentifiers:
            return PoeticNumberAssignmentExpr(target: self)
        case String.indexingIdentifiers:
            return IndexingLocationExpr(target: self)
        default:
            throw UnexpectedIdentifierError(got: id, parsing: self, expecting: Set(String.poeticNumberIdentifiers ∪ String.sayPoeticStringIdentifiers))
        }
    }

    func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            return self
        case let id as IdentifierLex:
            return try fromIdentifier(id)
        case is StringLex, is NumberLex, is DelimiterLex:
            throw UnexpectedLexemeError(got: lex, parsing: self)
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal class PronounExpr: FinalizedLocationExpr {
    var isTerminated: Bool = false
    let prettyName: String = "Pronoun"
}

internal class VariableNameExpr: FinalizedLocationExpr {
    let name: String
    var isTerminated: Bool = false
    var prettyName: String { "Variable Name (=\(name))" }

    init(name n: String) {
        name = n.lowercased()
    }
}

internal class IndexingLocationExpr: LocationExpr {
    let target: LocationExpr
    lazy var index: Expr = VanillaExpr(parent: self)
    var isTerminated: Bool = false
    var prettyName: String { "Indexing (=\(target)[\(index)])" }

    var canTerminate: Bool { !(index is VanillaExpr) }

    init(target t: LocationExpr) {
        target = t
    }

    func pushThrough(_ lex: Lex) throws {
        index = try index.push(lex)
    }

    func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            try pushThrough(lex)
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            return self
        case is IdentifierLex, is StringLex, is NumberLex, is DelimiterLex:
            try pushThrough(lex)
            return self
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal class CommonVariableNameExpr: LocationExpr {
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

    func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            return self
        case let id as IdentifierLex:
            return fromIdentifier(id)
        case is StringLex, is NumberLex, is DelimiterLex:
            throw UnexpectedLexemeError(got: lex, parsing: self)
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal class ProperVariableNameExpr: LocationExpr {
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
        let newMe = finalize()
        return try newMe.push(lex)
    }

    func fromIdentifier(_ id: IdentifierLex) throws -> Expr {
        let word = id.literal
        if word.firstCharIsUpperCase {
            words.append(word)
            return self
        } else {
            return try pushToFinalVariable(id)
        }
    }

    func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            try terminate(lex)
            return finalize()
        case is WhitespaceLex, is CommentLex:
            return self
        case let id as IdentifierLex:
            return try fromIdentifier(id)
        case is DelimiterLex:
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

internal class PoeticNumberAssignmentExpr: AnyAssignmentExpr {
    var isTerminated: Bool = false
    var target: Expr
    private var _value = 0
    private var digit: Int? = nil
    var value: NumberExpr?
    let prettyName: String = "Poetic Number Assignment"

    init(target t: Expr) {
        // TODO check is LocationExpr
        target = t
    }

    var canTerminate: Bool { _value > 0 }

    func addToPoeticDigit(from id: IdentifierLex) {
        let n = id.poeticNumeralValue
        digit = (digit ?? 0) + n
    }

    func pushPoeticDigit() {
        if let n = digit {
            _value *= 10
            _value += n % 10
            digit = nil
        }
    }

    func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is WhitespaceLex, is CommentLex:
            pushPoeticDigit()
            return self
        case is NewlineLex:
            pushPoeticDigit()
            value = NumberExpr(literal: Double(_value))
            return try terminate(lex)
        case let id as IdentifierLex:
            addToPoeticDigit(from: id)
        break
        case is StringLex, is DelimiterLex, is NumberLex:
            throw UnexpectedLexemeError(got: lex, parsing: self)
        default:
            assertionFailure("unhandled lexeme")
        }
        return self
    }
}

internal class PoeticStringAssignmentExpr: AnyAssignmentExpr {
    var isTerminated: Bool = false
    var target: Expr
    private var _value: String?
    var value: StringExpr?
    let prettyName: String = "Poetic String Assignment"

    init(target t: Expr) {
        // TODO check is LocationExpr
        target = t
    }

    func append(_ s: String) {
        guard _value != nil else { _value = s; return }
        _value! += s
    }

    let canTerminate: Bool = true

    func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            value = StringExpr(literal: _value ?? "")
            return try terminate(lex)
        case is DelimiterLex, is NumberLex:
            append(lex.literal)
        case is IdentifierLex, is CommentLex, is StringLex:
            append(lex.prettyLiteral!)
        case is WhitespaceLex:
            if _value == nil {
                _value = ""
            } else {
                append(lex.literal)
            }
        default:
            assertionFailure("unhandled lexeme")
        }

        return self
    }
}

internal class AssignmentExpr: AnyAssignmentExpr {
    var isTerminated: Bool = false
    lazy var target: Expr = VanillaExpr(parent: self)
    lazy var value: Expr = VanillaExpr(parent: self)
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

    convenience init(expectingValue ev: Bool) {
        self.init(expectingTarget: !ev)
    }

    func pushThrough(_ lex: Lex) throws {
        if expectingTarget {
            target = try target.push(lex)
        } else {
            value = try value.push(lex)
        }
    }

    func fromIdentifier(_ id: IdentifierLex) throws {
        switch id.literal {
        case String.assignBeIdentifiers:
            guard expectingTarget && !(target is VanillaExpr) else {
                throw UnexpectedIdentifierError(got: id, parsing: self, expecting: String.assignIntoIdentifiers)
            }
            expectingTarget = false
        case String.assignIntoIdentifiers:
            guard expectingValue && !(value is VanillaExpr) else {
                throw UnexpectedIdentifierError(got: id, parsing: self, expecting: String.assignBeIdentifiers)
            }
            expectingValue = false
        default:
            try pushThrough(id)
        }
    }

    func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            try pushThrough(lex)
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            break
        case let id as IdentifierLex:
            try fromIdentifier(id)
        case is StringLex, is DelimiterLex, is NumberLex:
            try pushThrough(lex)
        default:
            assertionFailure("unhandled lexeme")
        }

        return self
    }
}

internal class InputExpr: Expr {
    var isTerminated: Bool = false
    var target: Expr?
    let prettyName: String = "Input"

    var canTerminate: Bool {
        target == nil || !(target is VanillaExpr)
    }

    func pushThrough(_ lex: Lex) throws {
        guard target != nil else {
            throw UnexpectedLexemeError(got: lex, parsing: self)
        }
        target = try target!.push(lex)
        guard target is VanillaExpr || target is LocationExpr else {
            throw UnexpectedExprError<LocationExpr>(got: target!, range:lex.range, parsing: self)
        }
    }

    func fromIdentifier(_ id: IdentifierLex) throws {
        switch id.literal {
        case String.toIdentifiers:
            target = VanillaExpr(parent: self)
        default:
            try pushThrough(id)
        }
    }

    func push(_ lex: Lex) throws -> Expr {
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
        case is StringLex, is DelimiterLex, is NumberLex:
            try pushThrough(lex)
        default:
            assertionFailure("unhandled lexeme")
        }

        return self
    }
}

internal class OutputExpr: Expr {
    var isTerminated: Bool = false
    lazy var target: Expr = VanillaExpr(parent: self)
    let prettyName: String = "Output"

    var canTerminate: Bool {
        !(target is VanillaExpr)
    }

    func pushThrough(_ lex: Lex) throws {
        target = try target.push(lex)
    }

    func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            try pushThrough(lex)
            return try terminate(lex)
        case is WhitespaceLex, is CommentLex:
            break
        case is IdentifierLex, is StringLex, is ContractionLex, is DelimiterLex, is NumberLex:
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
    func push(_ lex: Lex) throws -> Expr {
        switch lex {
        case is NewlineLex:
            return try terminate(lex)
        case is CommentLex, is WhitespaceLex:
            return self
        case is StringLex, is NumberLex, is DelimiterLex:
            throw LeafExprPushError(got: lex, parsing: self)
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal class StringExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: String
    var prettyName: String { "String (=\"\(literal)\")" }
    init(literal s: String) { literal = s }
}

internal class NumberExpr: LeafExpr {
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

internal class BoolExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: Bool
    var prettyName: String { "Boolean Value (=\"\(literal)\")" }
    init(literal b: Bool) { literal = b }
}

internal class NullExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: Int? = nil
    let prettyName: String = "Null Value"
}

internal class MysteriousExpr: LeafExpr {
    var isTerminated: Bool = false
    let literal: Int? = nil
    let prettyName: String = "Mysterious Value"
}
