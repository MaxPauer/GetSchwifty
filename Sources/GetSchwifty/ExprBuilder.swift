fileprivate extension Character {
    var isDot: Bool { self == "." }
}

fileprivate extension String {
    var firstCharIsUpperCase: Bool {
        return self.first?.isUppercase ?? false
    }

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

internal enum PartialExpr {
    case builder(ExprBuilder)
    case expr(ExprP)
}

internal protocol ExprBuilder: AnyObject, CustomStringConvertible {
    var prettyName: String { get }
    func partialPush(_ lex: Lex) throws -> ExprBuilder
    func push(_ lex: Lex) throws -> PartialExpr
    func build(inRange range: LexRange) throws -> ExprP

    func handleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder
    func handleWhitespaceLex(_ w: WhitespaceLex) throws -> ExprBuilder
    func handleCommentLex(_ c: CommentLex) throws -> ExprBuilder
    func handleStringLex(_ s: StringLex) throws -> ExprBuilder
    func handleNumberLex(_ n: NumberLex) throws -> ExprBuilder
    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder
}

extension ExprBuilder {
    var description: String {
        "[\(prettyName) Expression]"
    }

    fileprivate func build<T>(asChildOf parent: ExprBuilder, inRange range: LexRange) throws -> T {
        let ep = try self.build(inRange: range)
        guard let tep = ep as? T else {
            throw UnexpectedExprError<T>(got: ep, startPos: range.start, parsing: parent)
        }
        return tep
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        switch lex {
        case let i as IdentifierLex: return try handleIdentifierLex(i)
        case let w as WhitespaceLex: return try handleWhitespaceLex(w)
        case let c as CommentLex: return try handleCommentLex(c)
        case let s as StringLex: return try handleStringLex(s)
        case let n as NumberLex: return try handleNumberLex(n)
        case let d as DelimiterLex: return try handleDelimiterLex(d)
        default:
            assertionFailure("unhandled lexeme")
            return self
        }
    }

    func handleWhitespaceLex(_ w: WhitespaceLex) throws -> ExprBuilder {
        return self
    }

    func handleCommentLex(_ c: CommentLex) throws -> ExprBuilder {
        return self
    }

    func handleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: i, parsing: self)
    }

    func handleStringLex(_ s: StringLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: s, parsing: self)
    }

    func handleNumberLex(_ n: NumberLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: n, parsing: self)
    }

    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: d, parsing: self)
    }
}

internal protocol CanPushThrough: ExprBuilder {
    func pushThrough(_ lex: Lex) throws -> ExprBuilder
}
internal protocol PushesIdentifierThrough: CanPushThrough {}
internal protocol PushesStringThrough: CanPushThrough {}
internal protocol PushesNumberThrough: CanPushThrough {}
internal protocol PushesDelimiterThrough: CanPushThrough {}

internal extension PushesIdentifierThrough {
    func handleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder {
        return try pushThrough(i)
    }
}

internal extension PushesStringThrough {
    func handleStringLex(_ s: StringLex) throws -> ExprBuilder {
        return try pushThrough(s)
    }
}

internal extension PushesNumberThrough {
    func handleNumberLex(_ n: NumberLex) throws -> ExprBuilder {
        return try pushThrough(n)
    }
}

internal extension PushesDelimiterThrough {
    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        return try pushThrough(d)
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

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
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

    func handleStringLex(_ s: StringLex) -> ExprBuilder {
        return StringExprBuilder(literal: s.literal)
    }

    func handleNumberLex(_ n: NumberLex) throws -> ExprBuilder {
        return try NumberExprBuilder(from: n, in: bestErrorLocation)
    }

    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: d, parsing: bestErrorLocation)
    }
}

internal protocol FinalizedLocationExprBuilder: SingleExprBuilder {}

extension FinalizedLocationExprBuilder {
    var canTerminate: Bool { true }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
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
                String.poeticNumberIdentifiers ∪ String.sayPoeticStringIdentifiers ∪ String.indexingIdentifiers)
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

internal class IndexingLocationExprBuilder:
        SingleExprBuilder, PushesIdentifierThrough, PushesStringThrough, PushesNumberThrough, PushesDelimiterThrough {
    let target: ExprBuilder
    lazy var index: ExprBuilder = VanillaExprBuilder(parent: self)

    var prettyName: String { "Indexing (=\(target)[\(index)])" }

    init(target t: ExprBuilder) {
        target = t
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        index = try index.partialPush(lex)
        return self
    }

    func build(inRange range: LexRange) throws -> ExprP {
        let t: IndexableExprP = try target.build(asChildOf: self, inRange: range)
        let i: ValueExprP = try index.build(asChildOf: self, inRange: range)
        return IndexingExpr(source: t, operand: i)
    }
}

internal class CommonVariableNameExprBuilder: SingleExprBuilder {
    let first: String
    var prettyName: String { "Variable Name (unfinished=\(first) …)" }

    init(first f: String) {
        first = f
    }

    func build(inRange range: LexRange) throws -> ExprP {
        throw UnexpectedEOLError(startPos: range.start, parsing: self)
    }

    func handleIdentifierLex(_ id: IdentifierLex) -> ExprBuilder {
        let word = id.literal
        return VariableNameExprBuilder(name: "\(first) \(word)")
    }
}

internal class ProperVariableNameExprBuilder: SingleExprBuilder, PushesDelimiterThrough {
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

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        let newMe = finalize()
        return try newMe.partialPush(lex)
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        let word = id.literal
        if word.firstCharIsUpperCase {
            words.append(word)
            return self
        } else {
            return try pushThrough(id)
        }
    }
}

internal class PoeticConstantAssignmentExprBuilder: SingleExprBuilder {
    let prettyName: String = "Poetic Constant Assignment"
    private var target: ExprBuilder
    lazy private var constant: ExprBuilder = VanillaExprBuilder(parent: self)

    init(target t: ExprBuilder, constantId id: IdentifierLex) throws {
        target = t
        constant = try constant.partialPush(id)
    }

    func build(inRange range: LexRange) throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self, inRange: range)
        let v: ValueExprP = try constant.build(asChildOf: self, inRange: range)
        return VoidCallExpr(head: .assign, target: t, source: v, arg: nil)
    }

    func handleIdentifierLex(_: IdentifierLex) throws -> ExprBuilder {
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

internal class PoeticNumberAssignmentExprBuilder: SingleExprBuilder {
    var target: ExprBuilder
    private var value = 0.0
    private var decimalDigit: UInt = 0
    private var digit: Int? = nil
    let prettyName: String = "Poetic Number Assignment"

    init(target t: ExprBuilder) {
        target = t
    }

    func addToPoeticDigit(from id: IdentifierLex) {
        let n = id.poeticNumeralValue
        digit = (digit ?? 0) + n
    }

    func pow10(_ n: UInt) -> UInt {
        var m: UInt = 1
        for _ in 0..<n { m *= 10 }
        return m
    }

    @discardableResult
    func pushPoeticDigit() -> ExprBuilder {
        if let n = digit {
            if decimalDigit == 0 {
                value *= 10
                value += Double(n % 10)
            } else {
                value += Double(n) / Double(pow10(decimalDigit))
                decimalDigit += 1
            }
            digit = nil
        }
        return self
    }

    func build(inRange range: LexRange) throws -> ExprP {
        pushPoeticDigit()
        let t: LocationExprP = try target.build(asChildOf: self, inRange: range)
        return VoidCallExpr(head: .assign, target: t, source: NumberExpr(literal: Double(value)), arg: nil)
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        if value == 0 {
            switch id.literal {
            case String.constantIdentifiers:
                return try PoeticConstantAssignmentExprBuilder(target: target, constantId: id)
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
        if decimalDigit == 0 && w.literal.firstCharIsDot {
            decimalDigit = 1
        }
        return self
    }
}

internal class PoeticStringAssignmentExprBuilder:
        SingleExprBuilder, PushesDelimiterThrough, PushesIdentifierThrough, PushesNumberThrough, PushesStringThrough {
    var target: ExprBuilder
    private var value: String?
    let prettyName: String = "Poetic String Assignment"

    init(target t: ExprBuilder) {
        target = t
    }

    func build(inRange range: LexRange) throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self, inRange: range)
        return VoidCallExpr(head: .assign, target: t, source: StringExpr(literal: value ?? ""), arg: nil)
    }

    func append(_ s: String) {
        if value == nil { value = "" }
        value! += s
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
        if value == nil {
            value = ""
        } else {
            append(w.literal)
        }
        return self
    }
}

internal class AssignmentExprBuilder: SingleExprBuilder, PushesDelimiterThrough, PushesNumberThrough, PushesStringThrough {
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
        return VoidCallExpr(head: .assign, target: t, source: s, arg: nil)
    }

    @discardableResult
    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        if expectingTarget {
            target = try target.partialPush(lex)
        } else {
            value = try value.partialPush(lex)
        }
        return self
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
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
        return self
    }
}

internal class CrementExprBuilder: SingleExprBuilder, PushesNumberThrough, PushesStringThrough {
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
        let add = FunctionCallExpr(head: .add, args: [t, NumberExpr(literal: Double(value))])
        return VoidCallExpr(head: .assign, target: t, source: add, arg: nil)
    }

    @discardableResult
    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        guard !targetFinished else { throw UnexpectedLexemeError(got: lex, parsing: self) }
        target = try target.partialPush(lex)
        return self
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
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
        return self
    }

    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        guard !targetFinished else { return self }
        return try pushThrough(d)
    }
}

internal class InputExprBuilder: SingleExprBuilder, PushesDelimiterThrough, PushesNumberThrough, PushesStringThrough {
    var target: ExprBuilder?
    let prettyName: String = "Input"

    func build(inRange range: LexRange) throws -> ExprP {
        guard let target = target else { return VoidCallExpr(head: .scan, target: nil, source: nil, arg: nil) }
        let t: LocationExprP = try target.build(asChildOf: self, inRange: range)
        return VoidCallExpr(head: .scan, target: t, source: nil, arg: nil)
    }

    @discardableResult
    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        guard target != nil else {
            throw UnexpectedLexemeError(got: lex, parsing: self)
        }
        target = try target!.partialPush(lex)
        return self
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        switch id.literal {
        case String.toIdentifiers:
            target = VanillaExprBuilder(parent: self)
        default:
            try pushThrough(id)
        }
        return self
    }
}

internal class OutputExprBuilder:
        SingleExprBuilder, PushesDelimiterThrough, PushesIdentifierThrough, PushesNumberThrough, PushesStringThrough {
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    let prettyName: String = "Output"

    func build(inRange range: LexRange) throws -> ExprP {
        let s: ValueExprP = try target.build(asChildOf: self, inRange: range)
        return VoidCallExpr(head: .print, target: nil, source: s, arg: nil)
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        target = try target.partialPush(lex)
        return self
    }
}

internal class StringExprBuilder: SingleExprBuilder {
    let literal: String
    var prettyName: String { "String (=\"\(literal)\")" }
    init(literal s: String) { literal = s }

    func build(inRange _: LexRange) -> ExprP {
        return StringExpr(literal: literal)
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        switch id.literal {
        case String.indexingIdentifiers:
            return IndexingLocationExprBuilder(target: self)
        default:
            throw UnexpectedLexemeError(got: id, parsing: self)
        }
    }

    func handleStringLex(_ s: StringLex) throws -> ExprBuilder {
        return StringExprBuilder(literal: literal + s.literal)
    }
}

internal class NumberExprBuilder: SingleExprBuilder {
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

internal class BoolExprBuilder: SingleExprBuilder {
    let literal: Bool
    var prettyName: String { "Boolean Value (=\"\(literal)\")" }
    init(literal b: Bool) { literal = b }

    func build(inRange _: LexRange) -> ExprP {
        return BoolExpr(literal: literal)
    }
}

internal class NullExprBuilder: SingleExprBuilder {
    let prettyName: String = "Null Value"

    func build(inRange _: LexRange) -> ExprP {
        return NullExpr()
    }
}

internal class MysteriousExprBuilder: SingleExprBuilder {
    let prettyName: String = "Mysterious Value"

    func build(inRange _: LexRange) -> ExprP {
        return MysteriousExpr()
    }
}
