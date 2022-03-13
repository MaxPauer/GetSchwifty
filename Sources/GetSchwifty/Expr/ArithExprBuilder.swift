enum Precedence: Int, Equatable, Comparable {
    case logic   = 20
    case compare = 21
    case plus    = 22
    case times   = 23
    case not     = 24
    case call    = 25
    case index   = 26
    case literal = 99

    static func <(lhs: Precedence, rhs: Precedence) -> Bool { lhs.rawValue < rhs.rawValue }
}

extension FunctionCallExpr.Op {
    var precedence: Precedence {
        switch self {
        case .and, .orr, .nor: return .logic
        case .eq, .neq, .gt,
             .lt, .geq, .leq:  return .compare
        case .add, .sub:       return .plus
        case .mul, .div:       return .times
        case .not:             return .not
        case .pop, .custom:    return .call
        }
    }
}

internal protocol ArithExprBuilder: SingleExprBuilder {
    var precedence: Precedence { get }
    var isStatement: Bool { get }
    func preHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder?
    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder
}

extension IdentifierLex {
    func getOp() -> FunctionCallExpr.Op? {
        switch literal {
        case String.additionIdentifiers: return .add
        case String.subtractionIdentifiers: return .sub
        case String.multiplicationIdentifiers: return .mul
        case String.divisionIdentifiers: return .div
        case String.andIdentifiers: return .and
        case String.orIdentifiers: return .orr
        case String.norIdentifiers: return .nor
        case String.isntIdentifiers: return .neq
        case String.isIdentifiers: return .eq
        default: return nil
        }
    }
}

extension ArithExprBuilder {
    var isStatement: Bool { false }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        if let pre = try preHandleIdentifierLex(id) {
            return pre
        }

        if isStatement && String.isIdentifiers ~= id.literal {
            return PoeticNumberishAssignmentExprBuilder(target: self)
        }

        if let op = id.getOp(), op.precedence <= self.precedence {
            return BiArithExprBuilder(op: op, lhs: self)
        }

        return try postHandleIdentifierLex(id)
    }

    func preHandleIdentifierLex(_ id: IdentifierLex) -> ExprBuilder? {
        return nil
    }
}

internal class BiArithExprBuilder:
        ArithExprBuilder, PushesStringLexThroughP, PushesNumberLexThroughP, PushesDelimiterLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
    private(set) var op: FunctionCallExpr.Op
    var opMustContinueWith: Set<String> = Set()
    var hasRhs: Bool = false
    var lhs: ExprBuilder
    lazy var rhs: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    var precedence: Precedence { op.precedence }

    init(op o: FunctionCallExpr.Op, lhs l: ExprBuilder) {
        op = o
        lhs = l
    }

    func build() throws -> ExprP {
        let l: ValueExprP = try lhs.build(asChildOf: self)
        let r: ValueExprP = try rhs.build(asChildOf: self)
        return FunctionCallExpr(head: op, args: [l,r], range: range)
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        guard opMustContinueWith.isEmpty else {
            throw UnexpectedLexemeError(got: lex, parsing: self)
        }
        hasRhs = true
        rhs = try rhs.partialPush(lex)
        return self
    }

    func preHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder? {
        if opMustContinueWith ~= id.literal {
            switch id.literal {
            case String.thanIdentifiers,
                 String.asIdentifiers:
                opMustContinueWith = Set()
                return self
            case String.lowIdentifiers:
                self.op = .leq
                opMustContinueWith = String.asIdentifiers
                return self
            case String.highIdentifiers:
                self.op = .geq
                opMustContinueWith = String.asIdentifiers
                return self
            default:
                break
            }
        } else if !opMustContinueWith.isEmpty {
            throw UnexpectedIdentifierError(got: id, parsing: self, expecting: opMustContinueWith)
        } else if self.op == .eq && !hasRhs {
            switch id.literal {
            case String.higherIdentifiers:
                self.op = .gt
                opMustContinueWith = String.thanIdentifiers
                return self
            case String.lowerIdentifiers:
                self.op = .lt
                opMustContinueWith = String.thanIdentifiers
                return self
            case String.asIdentifiers:
                opMustContinueWith = String.highIdentifiers ∪ String.lowIdentifiers
                return self
            default:
                break
            }
        }

        return nil
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        return try pushThrough(id)
    }
}

internal class UnArithExprBuilder:
        ArithExprBuilder, PushesStringLexThroughP, PushesNumberLexThroughP, PushesDelimiterLexThroughP, IgnoresCommentLexP, IgnoresWhitespaceLexP {
    let op: FunctionCallExpr.Op
    lazy var rhs: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    init(op o: FunctionCallExpr.Op) {
        op = o
    }

    var precedence: Precedence { op.precedence }

    func build() throws -> ExprP {
        let r: ValueExprP = try rhs.build(asChildOf: self)
        return FunctionCallExpr(head: op, args: [r], range: range)
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        rhs = try rhs.partialPush(lex)
        return self
    }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        return try pushThrough(id)
    }
}
