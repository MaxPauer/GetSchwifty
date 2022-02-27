extension FunctionCallExpr.Op {
    var precedence: Int {
        switch self {
        case .and, .orr, .nor: return 1
        case .eq, .neq, .gt,
             .lt, .geq, .leq:  return 2
        case .add, .sub:       return 3
        case .mul, .div:       return 4
        case .not:             return 5
        case .pop, .custom:    return 6
        }
    }

    static func <=(lhs: Self, rhs: Self) -> Bool {
        lhs.precedence <= rhs.precedence
    }
}

internal protocol ArithExprBuilder: SingleExprBuilder {
    var op: FunctionCallExpr.Op { get set }
    var rhs: ExprBuilder { get set }
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

internal class BiArithExprBuilder: ArithExprBuilder, PushesStringThrough, PushesNumberThrough, PushesDelimiterThrough {
    var op: FunctionCallExpr.Op
    var opMustContinueWith: Set<String> = Set()
    var hasRhs: Bool = false
    var lhs: ExprBuilder
    lazy var rhs: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

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

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
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

        if let op = id.getOp(), op <= self.op {
            return self |=> BiArithExprBuilder(op: op, lhs: self)
        }
        return try pushThrough(id)
    }
}

internal class UnArithExprBuilder: ArithExprBuilder, PushesStringThrough, PushesNumberThrough, PushesDelimiterThrough {
    var op: FunctionCallExpr.Op
    lazy var rhs: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    init(op o: FunctionCallExpr.Op) {
        op = o
    }

    func build() throws -> ExprP {
        let r: ValueExprP = try rhs.build(asChildOf: self)
        return FunctionCallExpr(head: op, args: [r], range: range)
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        rhs = try rhs.partialPush(lex)
        return self
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        if let op = id.getOp(), op <= self.op {
            return self |=> BiArithExprBuilder(op: op, lhs: self)
        }
        return try pushThrough(id)
    }
}
