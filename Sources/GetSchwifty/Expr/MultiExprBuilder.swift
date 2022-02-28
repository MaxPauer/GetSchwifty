internal protocol MultiExprBuilder: ExprBuilder {
    var currentExpr: ExprBuilder { get set }
    func push(_ expr: ExprP) throws
}

extension MultiExprBuilder {
    func push(_ lex: Lex) throws -> PartialExpr {
        let curr = try currentExpr.push(lex)
        switch curr {
        case .expr(let e):
            if e is NopExpr {
                return .expr(try build())
            }
            try push(e)
            currentExpr = VanillaExprBuilder(startPos: lex.range.start)
        case .builder(let b):
            currentExpr = b
        }
        return .builder(self)
    }
}

internal class LoopExprBuilder: MultiExprBuilder {
    private let invertedLogic: Bool
    internal var range: LexRange!
    internal lazy var currentExpr: ExprBuilder = VanillaExprBuilder(parent: self)
    internal var subExprs = DLinkedList<ExprP>()
    private var condition: ValueExprP?

    init(invertedLogic i: Bool) {
        invertedLogic = i
    }

    func push(_ expr: ExprP) throws {
        if condition == nil {
            guard let c = expr as? ValueExprP else {
                throw UnexpectedExprError<ValueExprP>(got: expr, startPos: expr.range.start, parsing: self)
            }
            condition = c
        } else if !(expr is NopExpr) {
            subExprs.pushBack(expr)
        }
    }

    func build() throws -> ExprP {
        try push(currentExpr.build())

        let cc = invertedLogic ?
            FunctionCallExpr(head: .not, args: [condition!], range: range) : condition!

        return LoopExpr(condition: cc, loopBlock: Array(subExprs.frontToBack), range: range)
    }
}

internal class FunctionDeclExprBuilder: MultiExprBuilder {
    private let head: FinalizedLocationExprBuilder
    internal var range: LexRange!
    internal lazy var currentExpr: ExprBuilder = VanillaExprBuilder(parent: self)
    internal var subExprs = DLinkedList<ExprP>()
    private var args: [VariableNameExpr]?

    init(head h: FinalizedLocationExprBuilder) {
        head = h
    }

    func normalizeArgs(_ args: ExprP) throws -> [VariableNameExpr] {
        switch args {
        case let v as VariableNameExpr:
            return [v]
        case let l as ListExpr:
            return try l.members.map {
                guard let m = $0 as? VariableNameExpr else {
                    throw UnexpectedExprError<VariableNameExpr>(got: $0, startPos: $0.range.start, parsing: self)
                }
                return m
            }
        default:
            throw UnexpectedExprError<VariableNameExpr>(got: args, startPos: args.range.start, parsing: self)
        }
    }

        func push(_ expr: ExprP) throws {
        if args == nil {
            args = try normalizeArgs(expr)
        } else if !(expr is NopExpr) {
            subExprs.pushBack(expr)
        }
    }

    func build() throws -> ExprP {
        try push(currentExpr.build())

        let head = try self.head.build() as! VariableNameExpr
        return FunctionDeclExpr(head: head, args: args!, funBlock: Array(subExprs.frontToBack), range: range)
    }
}
