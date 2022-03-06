internal protocol EvalContext {
    var variables: [String: Any] { get set }
    var lastVariable: VariableNameExpr? { get set }
    func shout(_: Any)
    func listen() -> Any
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
        throw NonBooleanExprError(expr: expr)
    }

    func evalEq(_ lhs: ValueExprP, _ rhs: ValueExprP, _ op: (AnyHashable, AnyHashable) -> Bool) throws -> Bool {
        let l = try eval(lhs)
        guard let ll = l as? AnyHashable else { throw NonEquatableExprError(expr: lhs, val: l) }
        let r = try eval(rhs)
        guard let rr = r as? AnyHashable else { throw NonEquatableExprError(expr: rhs, val: r) }
        return op(ll, rr)
    }

    func evalMath(_ lhs: ValueExprP, _ rhs: ValueExprP, _ op: (Double, Double) -> Any) throws -> Any {
        let l = try eval(lhs)
        guard let ll = l as? Double else { throw NonNumericExprError(expr: lhs, val: l) }
        let r = try eval(rhs)
        guard let rr = r as? Double else { throw NonNumericExprError(expr: rhs, val: r) }
        return op(ll, rr)
    }

    func evalAdd(_ lhs: ValueExprP, _ rhs: ValueExprP) throws -> Any {
        let l = try eval(lhs)
        let r = try eval(rhs)
        switch (l, r) {
        case (let ll as Double, let rr as Double):
            return ll+rr
        case (_, is String),
             (is String, _):
            return "\(l)\(r)"
        case (_, is Double):
            throw NonNumericExprError(expr: lhs, val: l)
        default:
            throw NonNumericExprError(expr: rhs, val: r)
        }
    }

    func eval(_ expr: FunctionCallExpr) throws -> Any {
        switch expr.head {
        case .not: return try !evalTruthiness(expr.args[0])
        case .and: return try evalTruthiness(expr.args[0]) && evalTruthiness(expr.args[1])
        case .orr: return try evalTruthiness(expr.args[0]) || evalTruthiness(expr.args[1])
        case .nor: return try !(evalTruthiness(expr.args[0]) || evalTruthiness(expr.args[1]))
        case .eq:  return try evalEq(expr.args[0], expr.args[1], {$0 == $1})
        case .neq: return try evalEq(expr.args[0], expr.args[1], {$0 != $1})
        case .gt:  return try evalMath(expr.args[0], expr.args[1], {$0 > $1})
        case .lt:  return try evalMath(expr.args[0], expr.args[1], {$0 < $1})
        case .geq: return try evalMath(expr.args[0], expr.args[1], {$0 >= $1})
        case .leq: return try evalMath(expr.args[0], expr.args[1], {$0 <= $1})
        case .add: return try evalAdd(expr.args[0], expr.args[1])
        case .sub: return try evalMath(expr.args[0], expr.args[1], {$0 - $1})
        case .mul: return try evalMath(expr.args[0], expr.args[1], {$0 * $1})
        case .div: return try evalMath(expr.args[0], expr.args[1], {$0 / $1})
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
        case .print:  try shout(eval(expr.source!))
        case .scan:   try set(expr.target!, listen())
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
    var _listen: () -> Any
    var _shout: (Any) -> Void

    init(input inp: String, stdin: @escaping () -> Any = { NullExpr.NullValue() }, stdout: @escaping (Any) -> Void = {_ in}) {
        parser = Parser(input: inp)
        _listen = stdin
        _shout = stdout
    }

    mutating func step() throws -> Bool {
        guard let expr = try parser.next() else { return false }
        try _eval(expr)
        return true
    }

    mutating func run() throws {
        while try step() { }
    }

    func shout(_ v: Any) { _shout(v) }
    func listen() -> Any { _listen() }
}
