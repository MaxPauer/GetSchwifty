infix operator |=>

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

    var isVanilla: Bool { self is VanillaExprBuilder }

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
    private var _range: LexRange?

    var range: LexRange! {
        get {
            if _range == nil {
                _range = -parent!.range.end
            }
            return _range!
        } set{
            _range = newValue
        }
    }

    init(parent p: ExprBuilder) {
        parent = p
    }

    init(startPos: LexPos) {
        parent = nil
        range = -startPos
    }

    func build() -> ExprP {
        return NopExpr()
    }

    private var bestErrorLocation: ExprBuilder { parent ?? self }
    private var isStatement: Bool { parent == nil }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        let word = id.literal
        switch word {
        case \.isEmpty:
            return self
        case String.commonVariableIdentifiers:
            return CommonVariableNameExprBuilder(first: word, isStatement: isStatement)
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
            return PronounExprBuilder(isStatement: isStatement)
        case String.buildIdentifiers:
            return CrementExprBuilder(forIncrement: true)
        case String.knockIdentifiers:
            return CrementExprBuilder(forDecrement: true)
        case String.pushIdentifiers:
            return PushExprBuilder()
        case String.popIdentifiers:
            return PopExprBuilder()
        case String.notIdentifiers:
            return UnArithExprBuilder(op: .not)
        case String.turnIdentifiers:
            return RoundExprBuilder()
        case String.castIdentifiers:
            return VoidCallExprBuilder(op: .cast)
        case String.splitIdentifiers:
            return VoidCallExprBuilder(op: .split)
        case String.joinIdentifiers:
            return VoidCallExprBuilder(op: .join)

        case \.firstCharIsUpperCase:
            return ProperVariableNameExprBuilder(first: word, isStatement: isStatement)
        default:
            return VariableNameExprBuilder(name: word, isStatement: isStatement)
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

internal class AssignmentExprBuilder: SingleExprBuilder, PushesDelimiterThrough, PushesNumberThrough, PushesStringThrough {
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    lazy var value: ExprBuilder = VanillaExprBuilder(parent: self)
    var op: FunctionCallExpr.Op?
    var range: LexRange!

    private(set) var expectingTarget: Bool
    private var expectingValue: Bool { !expectingTarget }
    private var gotSomeValue: Bool { !value.isVanilla }
    private var gotSomeTarget: Bool { !target.isVanilla }

    init(expectingTarget et: Bool) {
        expectingTarget = et
    }

    convenience init(expectingValue ev: Bool) {
        self.init(expectingTarget: !ev)
    }

    func build() throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self)
        var s: ValueExprP = try value.build(asChildOf: self)
        if let op = op {
            s = FunctionCallExpr(head: op, args: [t,s])
        }
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
            guard expectingTarget else {
                throw UnexpectedIdentifierError(got: id, parsing: self, expecting: String.assignIntoIdentifiers)
            }
            guard gotSomeTarget else {
                throw UnexpectedLexemeError(got: id, parsing: self)
            }
            expectingTarget = false
        case String.assignIntoIdentifiers:
            guard expectingValue else {
                throw UnexpectedIdentifierError(got: id, parsing: self, expecting: String.assignBeIdentifiers)
            }
            guard gotSomeValue else {
                throw UnexpectedLexemeError(got: id, parsing: self)
            }
            expectingTarget = true
        case String.additionIdentifiers, String.subtractionIdentifiers,
             String.multiplicationIdentifiers, String.divisionIdentifiers:
            guard expectingValue && !gotSomeValue else {
                throw UnexpectedLexemeError(got: id, parsing: self)
            }
            op = id.getOp()!
        default:
            try pushThrough(id)
        }
        return self
    }
}

internal class PushExprBuilder: SingleExprBuilder, PushesDelimiterThrough, PushesNumberThrough, PushesStringThrough {
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    var value: ExprBuilder?
    var range: LexRange!

    private var expectingValue: Bool { value != nil }

    func build() throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self)
        guard expectingValue else {
            return VoidCallExpr(head: .push, target: t, source: nil, arg: nil)
        }
        let v: ValueExprP = try value!.build(asChildOf: self)
        return VoidCallExpr(head: .push, target: t, source: nil, arg: v)
    }

    @discardableResult
    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        if !expectingValue {
            target = try target.partialPush(lex)
        } else {
            value = try value!.partialPush(lex)
        }
        return self
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        switch id.literal {
        case String.withIdentifiers:
            value = VanillaExprBuilder(parent: self)
        case String.likeIdentifiers:
            value = self |=> PoeticNumberExprBuilder()
        default:
            try pushThrough(id)
        }
        return self
    }

    func handleWhitespaceLex(_ w: WhitespaceLex) throws -> ExprBuilder {
        return try pushThrough(w)
    }

    func handleCommentLex(_ c: CommentLex) throws -> ExprBuilder {
        return try pushThrough(c)
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

internal class RoundExprBuilder:
        SingleExprBuilder, PushesDelimiterThrough, PushesNumberThrough, PushesStringThrough {
    lazy var source: ExprBuilder = VanillaExprBuilder(parent: self)
    private var op: VoidCallExpr.Op?
    var range: LexRange!

    let expectedIdentifiers = String.upIdentifiers ∪ String.downIdentifiers ∪ String.roundIdentifiers

    func build() throws -> ExprP {
        guard let op = op else {
            throw UnfinishedExprError(parsing: self, expecting: expectedIdentifiers)
        }
        let s: LocationExprP = try source.build(asChildOf: self)
        return VoidCallExpr(head: op, target: s, source: s, arg: nil)
    }

    @discardableResult
    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        source = try source.partialPush(lex)
        return self
    }

    func handleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder {
        if op == nil {
            switch i.literal {
            case String.upIdentifiers:    op = .ceil
            case String.downIdentifiers:  op = .floor
            case String.roundIdentifiers: op = .round
            default:
                return try pushThrough(i)
            }
            return self
        }
        return try pushThrough(i)
    }
}

internal class VoidCallExprBuilder:
        SingleExprBuilder, PushesDelimiterThrough, PushesNumberThrough, PushesStringThrough {
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    let op: VoidCallExpr.Op
    var source: ExprBuilder?
    var arg: ExprBuilder?
    var range: LexRange!

    init(op o: VoidCallExpr.Op) {
        op = o
    }

    func build() throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self)
        let s: ValueExprP? = try source?.build(asChildOf: self)
        let a: ValueExprP? = try arg?.build(asChildOf: self)
        return VoidCallExpr(head: op, target: t, source: s, arg: a)
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        if arg != nil {
            arg = try arg!.partialPush(lex)
        } else {
            target = try target.partialPush(lex)
        }
        return self
    }

    func handleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder {
        switch i.literal {
        case String.intoIdentifiers:
            source = target
            target = VanillaExprBuilder(parent: self)
            return self
        case String.withIdentifiers:
            arg = VanillaExprBuilder(parent: self)
            return self
        default:
            return try pushThrough(i)
        }
    }
}

internal class CrementExprBuilder: SingleExprBuilder, PushesNumberThrough, PushesStringThrough {
    var targetFinished: Bool = false
    let isIncrement: Bool
    var isDecrement: Bool { !isIncrement }
    private var value: Int = 0
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
    private var target: ExprBuilder?
    private var hasTarget: Bool { target != nil }
    var range: LexRange!

    func build() throws -> ExprP {
        guard hasTarget else { return VoidCallExpr(head: .scan, target: nil, source: nil, arg: nil) }
        let t: LocationExprP = try target!.build(asChildOf: self)
        return VoidCallExpr(head: .scan, target: t, source: nil, arg: nil)
    }

    @discardableResult
    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        guard hasTarget else {
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

internal class FunctionCallExprBuilder:
        SingleExprBuilder, PushesDelimiterThrough, PushesIdentifierThrough, PushesNumberThrough, PushesStringThrough {
    var head: ExprBuilder
    lazy var args: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    init(head h: ExprBuilder) {
        head = h
    }

    func build() throws -> ExprP {
        let h: LocationExprP = try head.build(asChildOf: self)
        let a: ValueExprP = try args.build(asChildOf: self)
        return FunctionCallExpr(head: .custom, args: [h, a])
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        args = try args.partialPush(lex)
        return self
    }
}
