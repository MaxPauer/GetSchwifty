internal protocol MultiExprBuilder: ExprBuilder {
    var currentExpr: ExprBuilder { get set }
    var subExprs: DLinkedList<ExprP> { get set }
}

extension MultiExprBuilder {
    func push(_ lex: Lex) throws -> PartialExpr {
        let curr = try currentExpr.push(lex)
        switch curr {
        case .expr(let e):
            if e is NopExpr {
                return .expr(try build())
            }
            subExprs.pushBack(e)
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

    init(invertedLogic i: Bool) {
        invertedLogic = i
    }

    func build() throws -> ExprP {
        let curr: ExprP = try currentExpr.build()
        if subExprs.isEmpty || !(curr is NopExpr) {
            subExprs.pushBack(curr)
        }

        let condition = subExprs.popFront()!
        guard let c = condition as? ValueExprP else {
            throw UnexpectedExprError<ValueExprP>(got: condition, startPos: condition.range.start, parsing: self)
        }
        let cc = invertedLogic ?
            FunctionCallExpr(head: .not, args: [c], range: range) : c

        return LoopExpr(condition: cc, loopBlock: Array(subExprs.frontToBack), range: range)
    }
}

internal class FunctionDeclExprBuilder: MultiExprBuilder {
    private let head: FinalizedLocationExprBuilder
    internal var range: LexRange!
    internal lazy var currentExpr: ExprBuilder = VanillaExprBuilder(parent: self)
    internal var subExprs = DLinkedList<ExprP>()

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

    func build() throws -> ExprP {
        let curr: ExprP = try currentExpr.build()
        if subExprs.isEmpty || !(curr is NopExpr) {
            subExprs.pushBack(curr)
        }

        let head = try self.head.build() as! VariableNameExpr
        let args = try normalizeArgs(subExprs.popFront()!)
        return FunctionDeclExpr(head: head, args: args, funBlock: Array(subExprs.frontToBack), range: range)
    }
}
