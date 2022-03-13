internal protocol ExprP: PrettyNamed {
    var range: LexRange { get }
}

internal protocol ValueExprP: ExprP {}
internal protocol LocationExprP: ValueExprP {}

internal struct NopExpr: ExprP {
    let range: LexRange
}

internal struct PronounExpr: LocationExprP {
    let range: LexRange
}

internal struct VariableNameExpr: LocationExprP {
    let name: String
    let range: LexRange
}

internal struct LiteralExpr<T>: ValueExprP {
    let literal: T
    let range: LexRange
}

internal struct IndexingExpr: LocationExprP {
    let source: LocationExprP
    let operand: ValueExprP
    let range: LexRange
}

internal struct ListExpr: ValueExprP {
    let members: [ValueExprP]
    let range: LexRange
}

internal struct ConditionalExpr: ExprP {
    let condition: ValueExprP
    let trueBlock: [ExprP]
    let falseBlock: [ExprP]
    let range: LexRange
}

internal struct LoopExpr: ExprP {
    let condition: ValueExprP
    let loopBlock: [ExprP]
    let range: LexRange
}

internal struct ReturnExpr: ExprP {
    let value: ValueExprP
    let range: LexRange
}

internal struct ElseExpr: ExprP {
    let range: LexRange
}

internal struct BreakExpr: ExprP {
    let range: LexRange
}

internal struct ContinueExpr: ExprP {
    let range: LexRange
}

internal struct FunctionDeclExpr: ExprP {
    let head: VariableNameExpr
    let args: [VariableNameExpr]
    let funBlock: [ExprP]
    let range: LexRange
}

internal struct FunctionCallExpr: ValueExprP {
    enum Op {
        case not; case and; case orr; case nor; case eq
        case neq; case gt; case lt; case geq; case leq
        case add; case sub; case mul; case div; case pop
        case custom
    }
    let head: Op
    let args: [ValueExprP]
    let range: LexRange
}

internal struct VoidCallExpr: ExprP {
    enum Op {
        case assign; case print; case scan; case push
        case split; case join; case cast; case pop
        case ceil; case floor; case round
    }

    let head: Op
    let target: LocationExprP?
    let source: ValueExprP?
    let arg: ValueExprP?
    let range: LexRange
}
