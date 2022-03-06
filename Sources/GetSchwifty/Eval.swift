internal protocol EvalContext {
    var variables: [String: Any] { get set }
    var lastVariable: VariableNameExpr? { get set }
}

extension EvalContext {
    mutating func set(_ i: LocationExprP, _ newValue: Any) throws {
        switch i {
        case let v as VariableNameExpr:
            variables[v.name] = newValue
            lastVariable = v
        case _ as PronounExpr:
            guard let lv = lastVariable else {
                throw PronoundUsedBeforeAssignmentError(startPos: i.range.start)
            }
            try set(lv, newValue)
        case _ as IndexingExpr:
            return // TODO
        default:
            assertionFailure("unhandled LocationExprP")
        }
    }

    func get(_ i: LocationExprP) throws -> Any {
        switch i {
        case let v as VariableNameExpr:
            guard let value = variables[v.name] else {
                throw VariableReadError(variable: v)
            }
            return value
        case _ as PronounExpr:
            guard let lv = lastVariable else {
                throw PronoundUsedBeforeAssignmentError(startPos: i.range.start)
            }
            return try get(lv)
        case _ as IndexingExpr:
            return NullExpr.NullValue() // TODO
        default:
            assertionFailure("unhandled LocationExprP")
            return NullExpr.NullValue()
        }
    }

    func evalTruthiness(_ expr: ValueExprP) throws -> Bool {
        let i = try eval(expr)
        if let b = i as? Bool { return b }
        if let d = i as? Double { return d != 0 }
        if i is String { return true }
        if i is NullExpr.NullValue { return false }
        if i is MysteriousExpr.MysteriousValue { return false }
        throw NonBooleanExprError(startPos: expr.range.start)
    }

    func eval(_ expr: FunctionCallExpr) throws -> Any {
        switch expr.head {
        case .not: return try !evalTruthiness(expr.args[0])
        case .and: return try evalTruthiness(expr.args[0]) && evalTruthiness(expr.args[1])
        case .orr: return try evalTruthiness(expr.args[0]) || evalTruthiness(expr.args[1])
        case .nor: return try !(evalTruthiness(expr.args[0]) || evalTruthiness(expr.args[1]))
        case .eq:  return NullExpr.NullValue() // TODO
        case .neq: return NullExpr.NullValue() // TODO
        case .gt:  return NullExpr.NullValue() // TODO
        case .lt:  return NullExpr.NullValue() // TODO
        case .geq: return NullExpr.NullValue() // TODO
        case .leq: return NullExpr.NullValue() // TODO
        case .add: return NullExpr.NullValue() // TODO
        case .sub: return NullExpr.NullValue() // TODO
        case .mul: return NullExpr.NullValue() // TODO
        case .div: return NullExpr.NullValue() // TODO
        case .pop: return NullExpr.NullValue() // TODO
        case .custom: return NullExpr.NullValue() // TODO
        }
    }

    func eval(_ expr: ValueExprP) throws -> Any {
        switch expr {
        case let b as BoolExpr:
            return b.literal
        case let n as NumberExpr:
            return n.literal
        case let s as StringExpr:
            return s.literal
        case let n as NullExpr:
            return n.literal
        case let m as MysteriousExpr:
            return m.literal
        case let l as LocationExprP:
            return try get(l)
        case let l as ListExpr:
            return NullExpr.NullValue() // TODO
        case let f as FunctionCallExpr:
            return try eval(f)
        default:
            assertionFailure("unhandled ValueExprP")
            return NullExpr.NullValue()
        }
    }

    mutating func eval(_ expr: VoidCallExpr) throws {
        switch expr.head {
        case .assign: try set(expr.target!, try eval(expr.source!))
        case .print:  break // TODO
        case .scan:   break // TODO
        case .push:   break // TODO
        case .split:  break // TODO
        case .join:   break // TODO
        case .cast:   break // TODO
        case .ceil:   break // TODO
        case .floor:  break // TODO
        case .round:  break // TODO
        }
    }

    mutating func _eval(_ expr: ExprP) throws {
        switch expr {
        case let v as VoidCallExpr:
            try eval(v)
        case _ as ConditionalExpr:
            break // TODO
        case _ as LoopExpr:
            break // TODO
        case let f as FunctionCallExpr:
            _ = try eval(f)
        case _ as FunctionDeclExpr:
            break // TODO
        case is ReturnExpr,
             is ElseExpr,
             is BreakExpr,
             is ContinueExpr:
            break // TODO
        case is ValueExprP,
             is NopExpr:
            break
        default:
            assertionFailure("unhandled ExprP")
        }
    }
}

internal struct MainEvalContext: EvalContext {
    var variables = [String: Any]()
    var lastVariable: VariableNameExpr? = nil
    var parser: Parser

    init(input inp: String) {
        parser = Parser(input: inp)
    }

    mutating func step() throws -> Bool {
        guard let expr = try parser.next() else { return false }
        try _eval(expr)
        return true
    }

    mutating func run() throws {
        while try step() { }
    }
}
