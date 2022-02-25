internal protocol ExprP: PrettyNamed {}

internal protocol ValueExprP: ExprP {}
internal protocol IndexableExprP: ValueExprP {}
internal protocol LocationExprP: IndexableExprP {}

internal protocol LiteralExprP: ValueExprP {
    associatedtype LiteralT
    var literal: LiteralT { get }
}

internal struct NopExpr: ExprP {}

internal struct PronounExpr: LocationExprP {}

internal struct VariableNameExpr: LocationExprP {
    let name: String
}

internal struct BoolExpr: LiteralExprP {
    let literal: Bool
}

internal struct NumberExpr: LiteralExprP {
    let literal: Double
}

internal struct StringExpr: LiteralExprP, IndexableExprP {
    let literal: String
}

internal struct NullExpr: LiteralExprP {
    let literal: Int? = nil
}

internal struct MysteriousExpr: LiteralExprP {
    let literal: Int? = nil
}

internal struct IndexingExpr: LocationExprP {
    let source: IndexableExprP
    let operand: ValueExprP
}

internal struct ListExpr: ValueExprP {
    let members: [ValueExprP]
}

internal struct ConditionalExpr: ExprP {
    let condition: ValueExprP
    let trueBlock: [ExprP]
    let falseBlock: [ExprP]
}

internal struct LoopExpr: ExprP {
    let condition: ValueExprP
    let loopBlock: [ExprP]
}

internal struct ReturnExpr: ExprP {
    let value: ValueExprP
}

internal struct FunctionDeclExpr: ValueExprP {
    let args: [String]
    let funBlock: [ExprP]
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
}

internal struct VoidCallExpr: ExprP {
    enum Op {
        case assign; case print; case scan; case push
        case split; case join; case cast
        case ceil; case floor; case round
    }

    let head: Op
    let target: LocationExprP?
    let source: ValueExprP?
    let arg: ValueExprP?
}
