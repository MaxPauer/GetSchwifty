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

internal enum PartialExpr {
    case builder(ExprBuilder)
    case expr(ExprP)
}

internal protocol ExprBuilder: AnyObject, CustomStringConvertible {
    var prettyName: String { get }
    func partialPush(_ lex: Lex) throws -> ExprBuilder
    func push(_ lex: Lex) throws -> PartialExpr
    func build(inRange range: LexRange) throws -> ExprP
}

extension ExprBuilder {
    var description: String {
        "[\(prettyName) Expression]"
    }

    fileprivate func build<T>(asChildOf parent: ExprBuilder, inRange range: LexRange) throws -> T {
        let ep = try self.build(inRange: range)
        guard let tep = ep as? T else {
            throw UnexpectedExprError<T>(got: ep, range: range, parsing: parent)
        }
        return tep
    }
}

internal protocol SingleExprBuilder: ExprBuilder {}

extension SingleExprBuilder {

    func push(_ lex: Lex) throws -> PartialExpr {
        if lex is NewlineLex {
            return .expr(try build(inRange: lex.range))
        }
        return .builder(try partialPush(lex))
    }
}

internal class VanillaExprBuilder: SingleExprBuilder {
    let prettyName: String = "Vanilla"
    let parent: ExprBuilder?

    init(parent p: ExprBuilder?) {
        parent = p
    }

    func build(inRange _: LexRange) -> ExprP {
        return NopExpr()
    }

    private var bestErrorLocation: ExprBuilder { parent ?? self }

    func fromIdentifier(_ id: IdentifierLex) -> ExprBuilder {
        let word = id.literal
        switch word {
        case \.isEmpty:
            return self
        case String.commonVariableIdentifiers:
            return CommonVariableNameExprBuilder(first: word)
        case String.letAssignIdentifiers:
            return AssignmentExprBuilder(expectingTarget: true)
        case String.putAssignIdentifiers:
            return AssignmentExprBuilder(expectingValue: true)
        case String.listenInputIdentifiers:
            return InputExprBuilder()
        case String.sayOutputIdentifiers:
            return OutputExprBuilder()
        case String.emptyStringIdentifiers:
            return StringExprBuilder(literal: "")
        case String.trueIdentifiers:
            return BoolExprBuilder(literal: true)
        case String.falseIdentifiers:
            return BoolExprBuilder(literal: false)
        case String.nullIdentifiers:
            return NullExprBuilder()
        case String.mysteriousIdentifiers:
            return MysteriousExprBuilder()
        case String.pronounIdentifiers:
            return PronounExprBuilder()
        case String.buildIdentifiers:
            return CrementExprBuilder(forIncrement: true)
        case String.knockIdentifiers:
            return CrementExprBuilder(forDecrement: true)

        case \.firstCharIsUpperCase:
            return ProperVariableNameExprBuilder(first: word)
        default:
            return VariableNameExprBuilder(name: word)
        }
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
        case is WhitespaceLex, is CommentLex:
            return self
        case let id as IdentifierLex:
            return fromIdentifier(id)
        case let str as StringLex:
            return StringExprBuilder(literal: str.literal)
        case let num as NumberLex:
            return try NumberExprBuilder(from: num, in: bestErrorLocation)
        case is DelimiterLex:
            throw UnexpectedLexemeError(got: lex, parsing: bestErrorLocation)
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal protocol FinalizedLocationExprBuilder: SingleExprBuilder {}

extension FinalizedLocationExprBuilder {
    var canTerminate: Bool { true }

    func fromIdentifier(_ id: IdentifierLex) throws -> ExprBuilder {
        let word = id.literal
        switch word {
        case String.sayPoeticStringIdentifiers:
            return PoeticStringAssignmentExprBuilder(target: self)
        case String.poeticNumberIdentifiers:
            return PoeticNumberAssignmentExprBuilder(target: self)
        case String.indexingIdentifiers:
            return IndexingLocationExprBuilder(target: self)
        default:
            throw UnexpectedIdentifierError(got: id, parsing: self, expecting:
                Set((String.poeticNumberIdentifiers ∪ String.sayPoeticStringIdentifiers) ∪ String.indexingIdentifiers))
        }
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
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

internal class PronounExprBuilder: FinalizedLocationExprBuilder {
    let prettyName: String = "Pronoun"

    func build(inRange _: LexRange) -> ExprP {
        return PronounExpr()
    }
}

internal class VariableNameExprBuilder: FinalizedLocationExprBuilder {
    let name: String
    var prettyName: String { "Variable Name (=\(name))" }

    init(name n: String) {
        name = n.lowercased()
    }

    func build(inRange _: LexRange) -> ExprP {
        return VariableNameExpr(name: name)
    }
}

internal class IndexingLocationExprBuilder: SingleExprBuilder {
    let target: ExprBuilder
    lazy var index: ExprBuilder = VanillaExprBuilder(parent: self)

    var prettyName: String { "Indexing (=\(target)[\(index)])" }

    init(target t: ExprBuilder) {
        target = t
    }

    func pushThrough(_ lex: Lex) throws {
        index = try index.partialPush(lex)
    }

    func build(inRange range: LexRange) throws -> ExprP {
        let t: IndexableExprP = try target.build(asChildOf: self, inRange: range)
        let i: ValueExprP = try index.build(asChildOf: self, inRange: range)
        return IndexingExpr(source: t, operand: i)
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
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

internal class CommonVariableNameExprBuilder: SingleExprBuilder {
    let first: String
    var prettyName: String { "Variable Name (unfinished=\(first) …)" }

    init(first f: String) {
        first = f
    }

    func build(inRange range: LexRange) throws -> ExprP {
        throw UnexpectedEOLError(range: range, parsing: self)
    }

    func fromIdentifier(_ id: IdentifierLex) -> ExprBuilder {
        let word = id.literal
        return VariableNameExprBuilder(name: "\(first) \(word)")
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
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

internal class ProperVariableNameExprBuilder: SingleExprBuilder {
    private(set) var words: [String]
    var prettyName: String { "Variable Name (unfinished=\(name) …)" }

    init(first: String) {
        words = [first]
    }

    private var name: String { words.joined(separator: " ") }

    func build(inRange range: LexRange) throws -> ExprP {
        return finalize().build(inRange: range)
    }

    func finalize() -> VariableNameExprBuilder {
        VariableNameExprBuilder(name: name)
    }

    func pushToFinalVariable(_ lex: Lex) throws -> ExprBuilder {
        let newMe = finalize()
        return try newMe.partialPush(lex)
    }

    func fromIdentifier(_ id: IdentifierLex) throws -> ExprBuilder {
        let word = id.literal
        if word.firstCharIsUpperCase {
            words.append(word)
            return self
        } else {
            return try pushToFinalVariable(id)
        }
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
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

internal class PoeticNumberAssignmentExprBuilder: SingleExprBuilder {
    var target: ExprBuilder
    private var value = 0
    private var digit: Int? = nil
    let prettyName: String = "Poetic Number Assignment"

    init(target t: ExprBuilder) {
        target = t
    }

    func addToPoeticDigit(from id: IdentifierLex) {
        let n = id.poeticNumeralValue
        digit = (digit ?? 0) + n
    }

    func pushPoeticDigit() {
        if let n = digit {
            value *= 10
            value += n % 10
            digit = nil
        }
    }

    func build(inRange range: LexRange) throws -> ExprP {
        pushPoeticDigit()
        let t: LocationExprP = try target.build(asChildOf: self, inRange: range)
        return AssignmentExpr(target: t, source: NumberExpr(literal: Double(value)))
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
        case is WhitespaceLex, is CommentLex:
            pushPoeticDigit()
            return self
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

internal class PoeticStringAssignmentExprBuilder: SingleExprBuilder {
    var target: ExprBuilder
    private var value: String?
    let prettyName: String = "Poetic String Assignment"

    init(target t: ExprBuilder) {
        target = t
    }

    func build(inRange range: LexRange) throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self, inRange: range)
        return AssignmentExpr(target: t, source: StringExpr(literal: value ?? ""))
    }

    func append(_ s: String) {
        guard value != nil else { value = s; return }
        value! += s
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
        case is DelimiterLex, is NumberLex:
            append(lex.literal)
        case is IdentifierLex, is CommentLex, is StringLex:
            append(lex.prettyLiteral!)
        case is WhitespaceLex:
            if value == nil {
                value = ""
            } else {
                append(lex.literal)
            }
        default:
            assertionFailure("unhandled lexeme")
        }

        return self
    }
}

internal class AssignmentExprBuilder: SingleExprBuilder {
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    lazy var value: ExprBuilder = VanillaExprBuilder(parent: self)
    let prettyName: String = "Assignment"

    private(set) var expectingTarget: Bool
    private var expectingValue: Bool { !expectingTarget }

    init(target t: ExprBuilder, value v: ExprBuilder) {
        expectingTarget = false
        target = t
        value = v
    }

    init(expectingTarget et: Bool) {
        expectingTarget = et
    }

    convenience init(expectingValue ev: Bool) {
        self.init(expectingTarget: !ev)
    }

    func build(inRange range: LexRange) throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self, inRange: range)
        let s: ValueExprP = try value.build(asChildOf: self, inRange: range)
        return AssignmentExpr(target: t, source: s)
    }

    func pushThrough(_ lex: Lex) throws {
        if expectingTarget {
            target = try target.partialPush(lex)
        } else {
            value = try value.partialPush(lex)
        }
    }

    func fromIdentifier(_ id: IdentifierLex) throws {
        switch id.literal {
        case String.assignBeIdentifiers:
            guard expectingTarget && !(target is VanillaExprBuilder) else {
                throw UnexpectedIdentifierError(got: id, parsing: self, expecting: String.assignIntoIdentifiers)
            }
            expectingTarget = false
        case String.assignIntoIdentifiers:
            guard expectingValue && !(value is VanillaExprBuilder) else {
                throw UnexpectedIdentifierError(got: id, parsing: self, expecting: String.assignBeIdentifiers)
            }
            expectingTarget = true
        default:
            try pushThrough(id)
        }
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
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

internal class CrementExprBuilder: SingleExprBuilder {
    var targetFinished: Bool = false
    var isIncrement: Bool
    var isDecrement: Bool { !isIncrement }
    var value: Int = 0
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    let prettyName: String = "In-/Decrement"

    init(forIncrement inc: Bool) {
        isIncrement = inc
    }
    init(forDecrement dec: Bool) {
        isIncrement = !dec
    }

    func build(inRange range: LexRange) throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self, inRange: range)
        return AssignmentExpr(target: t, source: ArithmeticExpr(lhs: t, rhs: NumberExpr(literal: Double(value)), op: .add))
    }

    func pushThrough(_ lex: Lex) throws {
        guard !targetFinished else { throw UnexpectedLexemeError(got: lex, parsing: self) }
        target = try target.partialPush(lex)
    }

    func fromIdentifier(_ id: IdentifierLex) throws {
        switch id.literal {
        case String.upIdentifiers:
            guard isIncrement else { throw UnexpectedIdentifierError(got: id, parsing: self, expecting: String.downIdentifiers ) }
            targetFinished = true
            value += 1
        case String.downIdentifiers:
            guard isDecrement else { throw UnexpectedIdentifierError(got: id, parsing: self, expecting: String.upIdentifiers ) }
            targetFinished = true
            value -= 1
        default:
            try pushThrough(id)
        }
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
        case is WhitespaceLex, is CommentLex:
            break
        case let id as IdentifierLex:
            try fromIdentifier(id)
        case is StringLex, is NumberLex:
            try pushThrough(lex)
        case is DelimiterLex:
            guard !targetFinished else { break }
            try pushThrough(lex)
        default:
            assertionFailure("unhandled lexeme")
        }

        return self
    }
}

internal class InputExprBuilder: SingleExprBuilder {
    var target: ExprBuilder?
    let prettyName: String = "Input"

    func build(inRange range: LexRange) throws -> ExprP {
        guard let target = target else { return InputExpr(target: nil) }
        let t: LocationExprP = try target.build(asChildOf: self, inRange: range)
        return InputExpr(target: t)
    }

    func pushThrough(_ lex: Lex) throws {
        guard target != nil else {
            throw UnexpectedLexemeError(got: lex, parsing: self)
        }
        target = try target!.partialPush(lex)
    }

    func fromIdentifier(_ id: IdentifierLex) throws {
        switch id.literal {
        case String.toIdentifiers:
            target = VanillaExprBuilder(parent: self)
        default:
            try pushThrough(id)
        }
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
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

internal class OutputExprBuilder: SingleExprBuilder {
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    let prettyName: String = "Output"

    func build(inRange range: LexRange) throws -> ExprP {
        let s: ValueExprP = try target.build(asChildOf: self, inRange: range)
        return OutputExpr(source: s)
    }

    func pushThrough(_ lex: Lex) throws {
        target = try target.partialPush(lex)
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
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

internal protocol LeafExprBuilder: SingleExprBuilder {}

extension LeafExprBuilder {
    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
        case is CommentLex, is WhitespaceLex:
            return self
        case is StringLex, is NumberLex, is DelimiterLex, is IdentifierLex:
            throw LeafExprPushError(got: lex, parsing: self)
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }
}

internal class StringExprBuilder: LeafExprBuilder {
    let literal: String
    var prettyName: String { "String (=\"\(literal)\")" }
    init(literal s: String) { literal = s }

    func build(inRange _: LexRange) -> ExprP {
        return StringExpr(literal: literal)
    }
}

internal class NumberExprBuilder: LeafExprBuilder {
    let literal: Double
    var prettyName: String { "Numberic Value (=\"\(literal)\")" }

    func build(inRange _: LexRange) -> ExprP {
        return NumberExpr(literal: literal)
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

internal class BoolExprBuilder: LeafExprBuilder {
    let literal: Bool
    var prettyName: String { "Boolean Value (=\"\(literal)\")" }
    init(literal b: Bool) { literal = b }

    func build(inRange _: LexRange) -> ExprP {
        return BoolExpr(literal: literal)
    }
}

internal class NullExprBuilder: LeafExprBuilder {
    let prettyName: String = "Null Value"

    func build(inRange _: LexRange) -> ExprP {
        return NullExpr()
    }
}

internal class MysteriousExprBuilder: LeafExprBuilder {
    let prettyName: String = "Mysterious Value"

    func build(inRange _: LexRange) -> ExprP {
        return MysteriousExpr()
    }
}
