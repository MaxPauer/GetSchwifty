infix operator |=>

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

internal protocol ExprBuilder: AnyObject, PrettyNamed {
    var range: LexRange! { get set }
    func partialPush(_ lex: Lex) throws -> ExprBuilder
    func push(_ lex: Lex) throws -> PartialExpr
    func build() throws -> ExprP

    func handleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder
    func handleWhitespaceLex(_ w: WhitespaceLex) throws -> ExprBuilder
    func handleCommentLex(_ c: CommentLex) throws -> ExprBuilder
    func handleStringLex(_ s: StringLex) throws -> ExprBuilder
    func handleNumberLex(_ n: NumberLex) throws -> ExprBuilder
    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder
}

extension ExprBuilder {
    internal func build<T>(asChildOf parent: ExprBuilder) throws -> T {
        let ep = try self.build()
        guard let tep = ep as? T else {
            throw UnexpectedExprError<T>(got: ep, startPos: range.start, parsing: parent)
        }
        return tep
    }

    static func |=> <E>(lhs: Self, rhs: E) -> E where E: ExprBuilder {
        rhs.range = -lhs.range.end
        return rhs
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        var newSelf: ExprBuilder = self

        switch lex {
        case let i as IdentifierLex: newSelf = try handleIdentifierLex(i)
        case let w as WhitespaceLex: newSelf = try handleWhitespaceLex(w)
        case let c as CommentLex: newSelf = try handleCommentLex(c)
        case let s as StringLex: newSelf = try handleStringLex(s)
        case let n as NumberLex: newSelf = try handleNumberLex(n)
        case let d as DelimiterLex: newSelf = try handleDelimiterLex(d)
        default:
            assertionFailure("unhandled lexeme")
        }

        newSelf.range = self.range + lex.range
        return newSelf
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
            return .expr(try build())
        }
        return .builder(try partialPush(lex))
    }
}

internal class VanillaExprBuilder: SingleExprBuilder {
    let parent: ExprBuilder?
    var range: LexRange!

    init(parent p: ExprBuilder) {
        parent = p
        range = -p.range.end
    }

    init(startPos: LexPos) {
        parent = nil
        range = -startPos
    }

    func build() -> ExprP {
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
        case String.pushIdentifiers:
            return PushExprBuilder()
        case String.popIdentifiers:
            return PopExprBuilder()

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

internal protocol ArithValueExprBuilder: SingleExprBuilder {
    func handleOtherIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder
}

extension ArithValueExprBuilder {
func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        switch id.literal {
        case String.additionIdentifiers:
            return ArithExprBuilder(op: .add, lhs: self)
        case String.subtractionIdentifiers:
            return ArithExprBuilder(op: .sub, lhs: self)
        case String.multiplicationIdentifiers:
            return ArithExprBuilder(op: .mul, lhs: self)
        case String.divisionIdentifiers:
            return ArithExprBuilder(op: .div, lhs: self)
        case String.andIdentifiers:
            return ArithExprBuilder(op: .and, lhs: self)
        case String.orIdentifiers:
            return ArithExprBuilder(op: .orr, lhs: self)
        case String.norIdentifiers:
            return ArithExprBuilder(op: .nor, lhs: self)
        default:
            return try handleOtherIdentifierLex(id)
        }
    }
}

internal protocol FinalizedLocationExprBuilder: ArithValueExprBuilder {}

extension FinalizedLocationExprBuilder {
    var canTerminate: Bool { true }

    func handleOtherIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
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
    var range: LexRange!

    func build() -> ExprP {
        return PronounExpr()
    }
}

internal class VariableNameExprBuilder: FinalizedLocationExprBuilder {
    let name: String
    var range: LexRange!

    init(name n: String) {
        name = n.lowercased()
    }

    func build() -> ExprP {
        return VariableNameExpr(name: name)
    }
}

internal class IndexingLocationExprBuilder:
        SingleExprBuilder, PushesIdentifierThrough, PushesStringThrough, PushesNumberThrough, PushesDelimiterThrough {
    let target: ExprBuilder
    lazy var index: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    init(target t: ExprBuilder) {
        target = t
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        index = try index.partialPush(lex)
        return self
    }

    func build() throws -> ExprP {
        let t: IndexableExprP = try target.build(asChildOf: self)
        let i: ValueExprP = try index.build(asChildOf: self)
        return IndexingExpr(source: t, operand: i)
    }
}

internal class CommonVariableNameExprBuilder: ExprBuilder {
    let first: String
    var range: LexRange!

    init(first f: String) {
        first = f
    }

    func push(_ lex: Lex) throws -> PartialExpr {
        if lex is NewlineLex {
            throw UnexpectedLexemeError(got: lex, parsing: self)
        }
        return .builder(try partialPush(lex))
    }

    func build() throws -> ExprP {
        assertionFailure("must not be called")
        return NopExpr()
    }

    func handleIdentifierLex(_ id: IdentifierLex) -> ExprBuilder {
        let word = id.literal
        return self |=> VariableNameExprBuilder(name: "\(first) \(word)")
    }
}

internal class ProperVariableNameExprBuilder: SingleExprBuilder, PushesDelimiterThrough {
    private(set) var words: [String]
    var range: LexRange!
    var name: String { words.joined(separator: " ") }

    init(first: String) {
        words = [first]
    }

    func build() throws -> ExprP {
        return finalize().build()
    }

    func finalize() -> VariableNameExprBuilder {
        self |=> VariableNameExprBuilder(name: name)
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
    private var target: ExprBuilder
    lazy private var constant: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    init(target t: ExprBuilder) throws {
        target = t
    }

    func build() throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self)
        let v: ValueExprP = try constant.build(asChildOf: self)
        return VoidCallExpr(head: .assign, target: t, source: v, arg: nil)
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

internal class PoeticNumberAssignmentExprBuilder: SingleExprBuilder {
    var target: ExprBuilder
    private var value = 0.0
    private var decimalDigit: UInt = 0
    private var digit: Int? = nil
    var range: LexRange!

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

    func build() throws -> ExprP {
        pushPoeticDigit()
        let t: LocationExprP = try target.build(asChildOf: self)
        return VoidCallExpr(head: .assign, target: t, source: NumberExpr(literal: Double(value)), arg: nil)
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        if value == 0 {
            switch id.literal {
            case String.constantIdentifiers:
                let newSelf = try self |=> PoeticConstantAssignmentExprBuilder(target: target)
                return try newSelf.partialPush(id)
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
    var range: LexRange!

    init(target t: ExprBuilder) {
        target = t
    }

    func build() throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self)
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
    var range: LexRange!

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

    func build() throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self)
        let s: ValueExprP = try value.build(asChildOf: self)
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

internal class PushExprBuilder: SingleExprBuilder, PushesDelimiterThrough, PushesNumberThrough, PushesStringThrough {
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    lazy var value: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    private(set) var expectingValue: Bool = false

    func build() throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self)
        guard expectingValue else {
            return VoidCallExpr(head: .push, target: t, source: nil, arg: nil)
        }
        let v: ValueExprP = try value.build(asChildOf: self)
        return VoidCallExpr(head: .push, target: t, source: nil, arg: v)
    }

    @discardableResult
    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        if !expectingValue {
            target = try target.partialPush(lex)
        } else {
            value = try value.partialPush(lex)
        }
        return self
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        switch id.literal {
        case String.withIdentifiers:
            expectingValue = true
        default:
            try pushThrough(id)
        }
        return self
    }
}

internal class PopExprBuilder:
        SingleExprBuilder, PushesDelimiterThrough, PushesNumberThrough, PushesStringThrough, PushesIdentifierThrough {
    lazy var source: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    func build() throws -> ExprP {
        let s: LocationExprP = try source.build(asChildOf: self)
        return FunctionCallExpr(head: .pop, args: [s])
    }

    @discardableResult
    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        source = try source.partialPush(lex)
        return self
    }
}

internal class CrementExprBuilder: SingleExprBuilder, PushesNumberThrough, PushesStringThrough {
    var targetFinished: Bool = false
    var isIncrement: Bool
    var isDecrement: Bool { !isIncrement }
    var value: Int = 0
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    init(forIncrement inc: Bool) {
        isIncrement = inc
    }

    init(forDecrement dec: Bool) {
        isIncrement = !dec
    }

    func build() throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self)
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
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    var hasTarget = false
    var range: LexRange!

    func build() throws -> ExprP {
        guard hasTarget else { return VoidCallExpr(head: .scan, target: nil, source: nil, arg: nil) }
        let t: LocationExprP = try target.build(asChildOf: self)
        return VoidCallExpr(head: .scan, target: t, source: nil, arg: nil)
    }

    @discardableResult
    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        guard hasTarget else {
            throw UnexpectedLexemeError(got: lex, parsing: self)
        }
        target = try target.partialPush(lex)
        return self
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        switch id.literal {
        case String.toIdentifiers:
            hasTarget = true
        default:
            try pushThrough(id)
        }
        return self
    }
}

internal class OutputExprBuilder:
        SingleExprBuilder, PushesDelimiterThrough, PushesIdentifierThrough, PushesNumberThrough, PushesStringThrough {
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    func build() throws -> ExprP {
        let s: ValueExprP = try target.build(asChildOf: self)
        return VoidCallExpr(head: .print, target: nil, source: s, arg: nil)
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        target = try target.partialPush(lex)
        return self
    }
}

internal class StringExprBuilder: ArithValueExprBuilder {
    let literal: String
    var range: LexRange!
    init(literal s: String) { literal = s }

    func build() -> ExprP {
        return StringExpr(literal: literal)
    }

    func handleOtherIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        switch id.literal {
        case String.indexingIdentifiers:
            return IndexingLocationExprBuilder(target: self)
        default:
            throw UnexpectedLexemeError(got: id, parsing: self)
        }
    }

    func handleStringLex(_ s: StringLex) throws -> ExprBuilder {
        return self |=> StringExprBuilder(literal: literal + s.literal)
    }
}

internal class NumberExprBuilder: ArithValueExprBuilder {
    let literal: Double
    var range: LexRange!

    func build() -> ExprP {
        return NumberExpr(literal: literal)
    }

    func handleOtherIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
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

internal class BoolExprBuilder: ArithValueExprBuilder {
    let literal: Bool
    var range: LexRange!

    init(literal b: Bool) { literal = b }

    func build() -> ExprP {
        return BoolExpr(literal: literal)
    }

    func handleOtherIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }
}

internal class NullExprBuilder: ArithValueExprBuilder {
    var range: LexRange!

    func build() -> ExprP {
        return NullExpr()
    }

    func handleOtherIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }
}

internal class MysteriousExprBuilder: ArithValueExprBuilder {
    var range: LexRange!

    func build() -> ExprP {
        return MysteriousExpr()
    }

    func handleOtherIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: id, parsing: self)
    }
}
