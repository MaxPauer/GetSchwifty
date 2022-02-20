internal protocol ExprP {}

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

internal struct AssignmentExpr: ExprP {
    let target: LocationExprP
    let source: ValueExprP
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

internal struct ArithmeticExpr: ValueExprP {
    enum Op {
        case add; case sub; case mul; case div;
    }

    let lhs: ValueExprP
    let rhs: ValueExprP
    let op: Op
}

internal struct InputExpr: ExprP {
    let target: LocationExprP?
}

internal struct OutputExpr: ExprP {
    let source: ValueExprP
}

internal struct ListExpr: ValueExprP {
    let members: [ValueExprP]
}

internal struct PushExpr: ExprP {
    let target: LocationExprP
    let source: ExprP
}

internal struct PopExpr: ExprP {
    let source: LocationExprP
}

internal struct SplitExpr: ExprP {
    let target: LocationExprP
    let source: ValueExprP
    let splitt: ValueExprP?
}

internal struct JoinExpr: ExprP {
    let target: LocationExprP
    let source: ValueExprP
    let splitt: ValueExprP?
}

internal struct CastExpr: ExprP {
    let target: LocationExprP
    let source: ValueExprP
    let radix: ValueExprP?
}

internal struct RoundingExpr: ExprP {
    enum Op {
        case ceil; case floor; case round
    }
    let target: LocationExprP
    let op: Op
}

internal struct ComparisonExpr: ValueExprP {
    enum Op {
        case eq; case neq; case gt; case lt; case geq; case leq
    }
    let lhs: ValueExprP
    let rhs: ValueExprP
    let op: Op
}

internal struct BinBooleanExpr: ValueExprP {
    enum Op {
        case and; case orr; case nor
    }
    let lhs: ValueExprP
    let rhs: ValueExprP
    let op: Op
}

internal struct BooleanNotExpr: ValueExprP {
    let operand: ValueExprP
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

internal struct FunctionExpr: ExprP {
    let args: [String]
    let funBlock: [ExprP]
}
