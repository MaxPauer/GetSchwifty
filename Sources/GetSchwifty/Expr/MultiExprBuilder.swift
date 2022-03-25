protocol MultiExprBuilder: ExprBuilder {
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
            currentExpr = VanillaExprBuilder(startPos: lex.range.end)
        case .builder(let b):
            currentExpr = b
        }
        return .builder(self)
    }

    func partialPush(_ lex: Lex) throws -> ExprBuilder {
        assertionFailure("should never be called")
        return self
    }
}

class LoopExprBuilder: MultiExprBuilder {
    private let invertedLogic: Bool
    var range: LexRange!
    lazy var currentExpr: ExprBuilder = VanillaExprBuilder(parent: self)
    var subExprs = DLinkedList<ExprP>()
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

        return LoopExpr(condition: cc, loopBlock: Array(subExprs.consumeFrontToBack), range: range)
    }
}

class FunctionDeclExprBuilder: MultiExprBuilder {
    private let head: FinalizedLocationExprBuilder
    var range: LexRange!
    lazy var currentExpr: ExprBuilder = VanillaExprBuilder(parent: self)
    var subExprs = DLinkedList<ExprP>()
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

        // swiftlint:disable force_cast
        let head = try self.head.build() as! VariableNameExpr
        return FunctionDeclExpr(head: head, args: args!, funBlock: Array(subExprs.consumeFrontToBack), range: range)
    }
}

class ConditionalExprBuilder: MultiExprBuilder {
    var range: LexRange!
    lazy var currentExpr: ExprBuilder = VanillaExprBuilder(parent: self)
    var condition: ValueExprP?
    var ifBlockExprs = DLinkedList<ExprP>()
    var elseBlockExprs = DLinkedList<ExprP>()
    var ifBlockFinished = false

    func push(_ expr: ExprP) throws {
        if condition == nil {
            guard let c = expr as? ValueExprP else {
                throw UnexpectedExprError<ValueExprP>(got: expr, startPos: expr.range.start, parsing: self)
            }
            condition = c
        } else if expr is NopExpr {
            return
        } else if expr is ElseExpr {
            ifBlockFinished = true
        } else if !ifBlockFinished {
            ifBlockExprs.pushBack(expr)
        } else {
            elseBlockExprs.pushBack(expr)
        }
    }

    func build() throws -> ExprP {
        try push(currentExpr.build())
        let cc = condition!
        return ConditionalExpr(condition: cc, trueBlock: Array(ifBlockExprs.consumeFrontToBack), falseBlock: Array(elseBlockExprs.consumeFrontToBack), range: range)
    }
}
