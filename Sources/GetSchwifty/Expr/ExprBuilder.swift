infix operator |=>

enum PartialExpr {
    case builder(ExprBuilder)
    case expr(ExprP)
}

protocol ExprBuilder: AnyObject, PrettyNamed {
    var range: LexRange! { get set }
    var consumesAnd: Bool { get }
    func partialPush(_: Lex) throws -> ExprBuilder
    func push(_: Lex) throws -> PartialExpr
    func build() throws -> ExprP
}

extension ExprBuilder {
    func build<T>(asChildOf parent: ExprBuilder) throws -> T {
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
    var consumesAnd: Bool { false }
}

protocol SingleExprBuilder: ExprBuilder {
    func handleIdentifierLex(_: IdentifierLex) throws -> ExprBuilder
    func handleWhitespaceLex(_: WhitespaceLex) throws -> ExprBuilder
    func handleCommentLex(_: CommentLex) throws -> ExprBuilder
    func handleStringLex(_: StringLex) throws -> ExprBuilder
    func handleNumberLex(_: NumberLex) throws -> ExprBuilder
    func handleDelimiterLex(_: DelimiterLex) throws -> ExprBuilder
}

extension SingleExprBuilder {
    func push(_ lex: Lex) throws -> PartialExpr {
        if lex is NewlineLex {
            return .expr(try build())
        }
        return .builder(try partialPush(lex))
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
}

class VanillaExprBuilder: SingleExprBuilder, IgnoresCommentLexP, IgnoresWhitespaceLexP {
    let parent: ExprBuilder?
    private var _range: LexRange?

    var range: LexRange! {
        get {
            if _range == nil {
                _range = -parent!.range.end
            }
            return _range!
        } set {
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
        return NopExpr(range: range)
    }

    private var bestErrorLocation: ExprBuilder { parent ?? self }
    private var isStatement: Bool { parent == nil }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
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
            return LiteralExprBuilder(literal: true)
        case String.falseIdentifiers:
            return LiteralExprBuilder(literal: false)
        case String.nullIdentifiers:
            return LiteralExprBuilder(literal: Rockstar.null)
        case String.mysteriousIdentifiers:
            return LiteralExprBuilder(literal: Rockstar.mysterious)
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
        case String.whileIdentifiers:
            return LoopExprBuilder(invertedLogic: false)
        case String.untilIdentifiers:
            return LoopExprBuilder(invertedLogic: true)
        case String.returnIdentifiers:
            return ReturnExprBuilder(first: word)
        case String.elseIdentifiers:
            return ElseExprBuilder()
        case String.ifIdentifiers:
            return ConditionalExprBuilder()
        case String.breakIdentifiers:
            return BreakExprBuilder()
        case String.continueIdentifiers:
            return ContinueExprBuilder()
        case String.takeIdentifiers:
            return ContinueExprBuilder(itToTheTop: true)

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

class AssignmentExprBuilder: SingleExprBuilder,
        PushesDelimiterLexThroughP, PushesNumberLexThroughP, PushesStringLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
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
            s = FunctionCallExpr(head: op, args: [t, s], range: range)
        }
        return VoidCallExpr(head: .assign, target: t, source: s, arg: nil, range: range)
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
            guard expectingValue else {
                throw UnexpectedLexemeError(got: id, parsing: self)
            }
            if !gotSomeValue {
                op = id.getOp()!
            } else {
                try pushThrough(id)
            }
        default:
            try pushThrough(id)
        }
        return self
    }
}

class PushExprBuilder: SingleExprBuilder,
        PushesDelimiterLexThroughP, PushesNumberLexThroughP, PushesStringLexThroughP {
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    var value: ExprBuilder?
    var range: LexRange!

    private var expectingValue: Bool { value != nil }

    func build() throws -> ExprP {
        let t: LocationExprP = try target.build(asChildOf: self)
        guard expectingValue else {
            return VoidCallExpr(head: .push, target: t, source: nil, arg: nil, range: range)
        }
        let v: ValueExprP = try value!.build(asChildOf: self)
        return VoidCallExpr(head: .push, target: t, source: nil, arg: v, range: range)
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

class RoundExprBuilder: SingleExprBuilder,
        PushesDelimiterLexThroughP, PushesNumberLexThroughP, PushesStringLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
    lazy var source: ExprBuilder = VanillaExprBuilder(parent: self)
    private var op: VoidCallExpr.Op?
    var range: LexRange!

    let expectedIdentifiers = String.upIdentifiers ∪ String.downIdentifiers ∪ String.roundIdentifiers

    func build() throws -> ExprP {
        guard let op = op else {
            throw UnfinishedExprError(parsing: self, expecting: expectedIdentifiers)
        }
        let s: LocationExprP = try source.build(asChildOf: self)
        return VoidCallExpr(head: op, target: s, source: s, arg: nil, range: range)
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

class VoidCallExprBuilder: SingleExprBuilder,
        PushesDelimiterLexThroughP, PushesNumberLexThroughP, PushesStringLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
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
        return VoidCallExpr(head: op, target: t, source: s, arg: a, range: range)
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

class CrementExprBuilder: SingleExprBuilder,
        PushesNumberLexThroughP, PushesStringLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
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
        let add = FunctionCallExpr(head: .add, args: [t, LiteralExpr(literal: Double(value), range: range)], range: range)
        return VoidCallExpr(head: .assign, target: t, source: add, arg: nil, range: range)
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

class InputExprBuilder: SingleExprBuilder,
        PushesDelimiterLexThroughP, PushesNumberLexThroughP, PushesStringLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
    private var target: ExprBuilder?
    private var hasTarget: Bool { target != nil }
    var range: LexRange!

    func build() throws -> ExprP {
        guard hasTarget else { return VoidCallExpr(head: .scan, target: nil, source: nil, arg: nil, range: range) }
        let t: LocationExprP = try target!.build(asChildOf: self)
        return VoidCallExpr(head: .scan, target: t, source: nil, arg: nil, range: range)
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

class OutputExprBuilder: SingleExprBuilder,
        PushesDelimiterLexThroughP, PushesNumberLexThroughP, PushesStringLexThroughP, PushesIdentifierLexThroughP,
        IgnoresCommentLexP, IgnoresWhitespaceLexP {
    lazy var target: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    func build() throws -> ExprP {
        let s: ValueExprP = try target.build(asChildOf: self)
        return VoidCallExpr(head: .print, target: nil, source: s, arg: nil, range: range)
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        target = try target.partialPush(lex)
        return self
    }
}

class ReturnExprBuilder: SingleExprBuilder,
        PushesDelimiterLexThroughP, PushesNumberLexThroughP, PushesStringLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
    let initialBackAllowed: Bool
    var backReceived: Bool = false
    lazy var arg: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    var backAllowed: Bool { (initialBackAllowed || !arg.isVanilla) && !backReceived }

    init(first: String) {
        initialBackAllowed = String.giveIdentifiers ~= first
    }

    func build() throws -> ExprP {
        let a: ValueExprP = try arg.build(asChildOf: self)
        return ReturnExpr(value: a, range: range)
    }

    @discardableResult
    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        arg = try arg.partialPush(lex)
        return self
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        switch id.literal {
        case String.backIdentifiers:
            if backAllowed {
                backReceived = true
            } else {
                throw UnexpectedIdentifierError(got: id, parsing: self, expecting: Set())
            }
        default:
            try pushThrough(id)
        }
        return self
    }
}

class ElseExprBuilder: SingleExprBuilder,
        ThrowsDelimiterLexP, ThrowsIdentifierLexP, ThrowsNumberLexP, ThrowsStringLexP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
    var range: LexRange!
    func build() -> ExprP {
        return ElseExpr(range: range)
    }
}

class BreakExprBuilder: SingleExprBuilder,
        ThrowsDelimiterLexP, ThrowsNumberLexP, ThrowsStringLexP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
    var range: LexRange!
    var acceptsIt: Bool = true
    var requiresDown: Bool = false

    func build() throws -> ExprP {
        guard !requiresDown else { throw UnfinishedExprError(parsing: self, expecting: String.downIdentifiers) }
        return BreakExpr(range: range)
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        switch id.literal {
        case String.itIdentifiers where acceptsIt:
            acceptsIt = false
            requiresDown = true
            return self
        case String.downIdentifiers where requiresDown:
            requiresDown = false
            return self
        default:
            let expecting = acceptsIt ? String.itIdentifiers : requiresDown ? String.downIdentifiers : Set()
            throw UnexpectedIdentifierError(got: id, parsing: self, expecting: expecting)
        }
    }
}

class ContinueExprBuilder: SingleExprBuilder,
        ThrowsDelimiterLexP, ThrowsNumberLexP, ThrowsStringLexP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
    var range: LexRange!
    var requires: DLinkedList<Set<String>>

    init() {
        requires = DLinkedList()
    }
    convenience init(itToTheTop: Bool) {
        self.init()
        if itToTheTop {
            requires.pushBack(String.itIdentifiers)
            requires.pushBack(String.toIdentifiers)
            requires.pushBack(String.theIdentifiers)
            requires.pushBack(String.topIdentifiers)
        }
    }

    func build() throws -> ExprP {
        guard requires.isEmpty else { throw UnfinishedExprError(parsing: self, expecting: requires.popFront()!) }
        return ContinueExpr(range: range)
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        guard !requires.isEmpty else {
            throw UnexpectedIdentifierError(got: id, parsing: self, expecting: Set())
        }
        switch id.literal {
        case requires.peekFront()!:
            _ = requires.popFront()
            return self
        default:
            throw UnexpectedIdentifierError(got: id, parsing: self, expecting: requires.popFront()!)
        }
    }
}
