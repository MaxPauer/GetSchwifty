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
    var op: FunctionCallExpr.Op { get }
    var rhs: ExprBuilder { get set }
}

extension ArithExprBuilder {
        func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        rhs = try rhs.partialPush(lex)
        return self
    }

    func getOp(_ id: IdentifierLex) -> FunctionCallExpr.Op? {
        switch id.literal {
        case String.additionIdentifiers: return .add
        case String.subtractionIdentifiers: return .sub
        case String.multiplicationIdentifiers: return .mul
        case String.divisionIdentifiers: return .div
        case String.andIdentifiers: return .and
        case String.orIdentifiers: return .orr
        case String.norIdentifiers: return .nor
        case String.isIdentifiers: return .eq
        default: return nil
        }
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        if let op = getOp(id), op <= self.op {
            return self |=> BiArithExprBuilder(op: op, lhs: self)
        }
        return try pushThrough(id)
    }
}

internal class BiArithExprBuilder: ArithExprBuilder, PushesStringThrough, PushesNumberThrough, PushesDelimiterThrough {
    let op: FunctionCallExpr.Op
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
        return FunctionCallExpr(head: op, args: [l,r])
    }
}

internal class UnArithExprBuilder: ArithExprBuilder, PushesStringThrough, PushesNumberThrough, PushesDelimiterThrough {
    let op: FunctionCallExpr.Op
    lazy var rhs: ExprBuilder = VanillaExprBuilder(parent: self)
    var range: LexRange!

    init(op o: FunctionCallExpr.Op) {
        op = o
    }

    func build() throws -> ExprP {
        let r: ValueExprP = try rhs.build(asChildOf: self)
        return FunctionCallExpr(head: op, args: [r])
    }
}
