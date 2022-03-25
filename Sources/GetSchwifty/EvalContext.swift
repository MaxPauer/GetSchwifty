class MainEvalContext: EvalContext {
    var variables = [String: Any]()
    var lastVariable: String?
    let debuggingSettings: DebuggingSettings

    var _exprs: AnySequence<ExprP>.Iterator
    var _listen: Rockin
    var _shout: Rockout

    init(input inp: AnySequence<ExprP>,
         debuggingSettings d: DebuggingSettings,
         rockin: @escaping Rockin,
         rockout: @escaping Rockout) {
        _exprs = inp.makeIterator()
        _listen = rockin
        _shout = rockout
        debuggingSettings = d
    }

    func getVariableOwner(_ n: String) -> EvalContext? {
        variables[n] != nil ? self : nil
    }

    func _setVariable(_ n: String, _ v: Any) {
        variables[n] = v
        lastVariable = n
    }
    func getVariable(_ n: String) -> Any? { variables[n] }
    func setVariable(_ n: String, _ v: Any) { _setVariable(n, v) }

    func step() throws -> Bool {
        guard let expr = _exprs.next() else { return false }
        try _eval(expr)
        return true
    }

    func run() throws {
        while try step() { }
    }

    func swiftify(_ v: Any) -> Any? {
        switch v {
        case let d as Double:
            if let i = Int(exactly: d) {
                return i
            }
            return d
        case let r as RockstarArray:
            return r.dict
        case is Rockstar.Null:
            return nil
        default:
            return v
        }
    }

    func shout(_ v: Any) throws {
        try _shout(swiftify(v))
    }

    func rockify(_ v: Any?) -> Any {
        guard let v = v else {
            return Rockstar.null
        }
        switch v {
        case let i as Int:
            return Double(i)
        case let i as UInt:
            return Double(i)
        case let a as [Any]:
            return RockstarArray(a)
        case let d as [AnyHashable: Any]:
            return RockstarArray(d)
        default:
            return v
        }
    }

    func listen() throws -> Any {
        rockify(try _listen())
    }

    func doReturn(_ r: ReturnExpr) throws { throw StrayExprError(expr: r) }
    func doBreak(_ b: BreakExpr) throws { throw StrayExprError(expr: b) }
    func doContinue(_ c: ContinueExpr) throws { throw StrayExprError(expr: c) }
}

protocol NestedEvalContext: EvalContext {
    var parent: EvalContext { get set }
    var variables: [String: Any] { get set }
    var _lastVariable: String? { get set }
}

extension NestedEvalContext {
    var debuggingSettings: DebuggingSettings {
        parent.debuggingSettings
    }

    func getVariable(_ n: String) -> Any? {
        variables[n] ?? parent.getVariable(n)
    }

    func getVariableOwner(_ n: String) -> EvalContext? {
        return variables[n] != nil ? self : parent.getVariableOwner(n)
    }

    func _setVariable(_ n: String, _ v: Any) {
        variables[n] = v
        lastVariable = n
    }

    func setVariable(_ n: String, _ v: Any) {
        if let owner = getVariableOwner(n) {
            owner._setVariable(n, v)
        } else {
            _setVariable(n, v)
        }
    }

    var lastVariable: String? {
        get {
            _lastVariable ?? parent.lastVariable
        } set {
            _lastVariable = newValue
        }
    }

    func shout(_ v: Any) throws { try parent.shout(v) }
    func listen() throws -> Any { try parent.listen() }
}

class ConditionalEvalContext: NestedEvalContext {
    var parent: EvalContext

    var variables = [String: Any]()
    var _lastVariable: String?
    var halt: Bool = false

    init(parent p: EvalContext) {
        parent = p
    }

    func doReturn(_ r: ReturnExpr) throws {
        halt = true
        try parent.doReturn(r)
    }

    func doBreak(_ b: BreakExpr) throws {
        halt = true
        try parent.doBreak(b)
    }

    func doContinue(_ c: ContinueExpr) throws {
        halt = true
        try parent.doContinue(c)
    }

    func eval(_ c: ConditionalExpr) throws {
        halt = false

        let cond = try evalTruthiness(c.condition)
        let block = cond ? c.trueBlock : c.falseBlock
        for e in block {
            try _eval(e)
            if halt { break }
        }
    }
}

class LoopEvalContext: NestedEvalContext {
    var parent: EvalContext

    var variables = [String: Any]()
    var _lastVariable: String?

    var didBreak: Bool = false
    var didContinue: Bool = false

    init(parent p: EvalContext) {
        parent = p
    }

    func doReturn(_ r: ReturnExpr) throws {
        didBreak = true
        try parent.doReturn(r)
    }

    func doBreak(_ b: BreakExpr) throws {
        didBreak = true
    }

    func doContinue(_ c: ContinueExpr) throws {
        didContinue = true
    }

    func eval(_ l: LoopExpr) throws {
        var loopCounter = debuggingSettings.maxLoopIterations
        rockLoop: while try evalTruthiness(l.condition) {
            didBreak = false
            didContinue = false

            for e in l.loopBlock {
                try _eval(e)
                if didBreak { break rockLoop }
                if didContinue { continue rockLoop }
            }

            guard let i = loopCounter else { continue }
            guard i > 0 else {
                throw MaxLoopRecursionExceededError(expr: l)
            }
            loopCounter = i-1
        }
    }
}

class RockFunEvalContext: NestedEvalContext {
    var parent: EvalContext
    let argNames: [String]
    let exprs: [ExprP]

    var variables = [String: Any]()
    var _lastVariable: String?

    var returnValue: Any?

    init(parent p: EvalContext, argNames a: [String], _ e: [ExprP]) {
        parent = p
        argNames = a
        exprs = e
    }

    func doReturn(_ r: ReturnExpr) throws {
        returnValue = try eval(r.value)
    }

    func doBreak(_ b: BreakExpr) throws {
        throw StrayExprError(expr: b)
    }

    func doContinue(_ c: ContinueExpr) throws {
        throw StrayExprError(expr: c)
    }

    func call(argVals: [Any], callPos: LexPos) throws -> Any {
        guard argNames.count == argVals.count else {
            throw InvalidArgumentCountError(expecting: argNames.count, got: argVals.count, startPos: callPos)
        }

        returnValue = nil
        variables.removeAll()
        for (a, v) in zip(argNames, argVals) {
            variables[a] = v
        }

        for e in exprs {
            try _eval(e)
            if let r = returnValue {
                return r
            }
        }

        return Rockstar.null
    }
}
