import Foundation

struct DebuggingSettings {
    let maxLoopRecursions: UInt?
}

protocol EvalContext: AnyObject {
    var lastVariable: String? { get set }
    var debuggingSettings: DebuggingSettings { get }

    func getVariableOwner(_ n: String) -> EvalContext?
    func getVariable(_ n: String) -> Any?
    func setVariable(_ n: String, _ v: Any)
    func _setVariable(_ n: String, _ v: Any)

    func shout(_: Any) throws
    func listen() throws -> Any

    func doReturn(_ r: ReturnExpr) throws
    func doBreak(_ b: BreakExpr) throws
    func doContinue(_ c: ContinueExpr) throws
}

extension EvalContext {
    func _set(_ v: VariableNameExpr, _ newValue: Any) throws {
        setVariable(v.name, newValue)
    }

    func _set(_ p: PronounExpr, _ newValue: Any) throws {
        guard let lv = lastVariable else {
            throw LocationError(location: p, op: .writePronoun)
        }
        setVariable(lv, newValue)
    }

    func _set(_ i: IndexingExpr, _ newValue: Any) throws {
        let source = try _get(i.source)
        let index = try eval(i.operand)
        guard let ii = index as? AnyHashable else {
            throw InvalidIndexError(expr: i.source, index: index)
        }
        switch source {
        case var arr as RockstarArray:
            arr[ii] = newValue
            try set(i.source, arr)
        default:
            var arr = RockstarArray()
            arr[0] = source
            arr[ii] = newValue
            try set(i.source, arr)
        }
    }

    func set(_ l: LocationExprP, _ newValue: Any) throws {
        switch l {
        case let v as VariableNameExpr:
            return try _set(v, newValue)
        case let p as PronounExpr:
            return try _set(p, newValue)
        case let i as IndexingExpr:
            return try _set(i, newValue)
        default:
            assertionFailure("unhandled LocationExprP")
        }
    }

    func _get(_ v: VariableNameExpr) throws -> Any {
        guard let value = getVariable(v.name) else {
            throw LocationError(location: v, op: .read)
        }
        return value
    }

    func _get(_ p: PronounExpr) throws -> Any {
        guard let lv = lastVariable else {
            throw LocationError(location: p, op: .readPronoun)
        }
        return getVariable(lv)!
    }

    func _get(_ i: IndexingExpr) throws -> Any {
        let source = try _get(i.source)
        let index = try eval(i.operand)
        guard let ii = index as? AnyHashable else {
            throw InvalidIndexError(expr: i.source, index: index)
        }
        switch source {
        case let arr as RockstarArray:
            return arr[ii]
        default:
            throw UnfitExprError(expr: i, val: source, op: .index)
        }
    }

    func _get(_ l: LocationExprP) throws -> Any {
        switch l {
        case let v as VariableNameExpr:
            return try _get(v)
        case let p as PronounExpr:
            return try _get(p)
        case let i as IndexingExpr:
            return try _get(i)
        default:
            assertionFailure("unhandled LocationExprP")
            return Rockstar.null
        }
    }

    func get(_ l: LocationExprP) throws -> Any {
        let val = try _get(l)
        if let arr = val as? RockstarArray {
            return Double(arr.length)
        }
        return val
    }

    func evalTruthiness(_ expr: ValueExprP) throws -> Bool {
        let i = try eval(expr)
        if let b = i as? Bool { return b }
        if let d = i as? Double { return d != 0 }
        if i is String { return true }
        if i is Rockstar.Null { return false }
        if i is Rockstar.Mysterious{ return false }
        throw UnfitExprError(expr: expr, val: i, op: .bool)
    }

    func implicitNull(_ v: Any) -> Any {
        v is Rockstar.Null ? 0.0 : v
    }

    func evalEq(_ lhs: ValueExprP, _ rhs: ValueExprP, _ op: (AnyHashable, AnyHashable) -> Bool) throws -> Bool {
        let l = implicitNull(try eval(lhs))
        guard let ll = l as? AnyHashable else { throw UnfitExprError(expr: lhs, val: l, op: .equation) }
        let r = implicitNull(try eval(rhs))
        guard let rr = r as? AnyHashable else { throw UnfitExprError(expr: rhs, val: r, op: .equation) }
        return op(ll, rr)
    }

    func evalMath(_ lhs: ValueExprP, _ rhs: ValueExprP, _ op: (Double, Double) -> Any) throws -> Any {
        let l = implicitNull(try eval(lhs))
        guard let ll = l as? Double else { throw UnfitExprError(expr: lhs, val: l, op: .numeric) }
        let r = implicitNull(try eval(rhs))
        guard let rr = r as? Double else { throw UnfitExprError(expr: rhs, val: r, op: .numeric) }
        return op(ll, rr)
    }

    func evalAdd(_ lhs: ValueExprP, _ rhs: ValueExprP) throws -> Any {
        let l = implicitNull(try eval(lhs))
        let r = implicitNull(try eval(rhs))
        switch (l, r) {
        case (let ll as Double, let rr as Double):
            return ll+rr
        case (_, is String),
             (is String, _):
            return "\(l)\(r)"
        case (_, is Double):
            throw UnfitExprError(expr: lhs, val: l, op: .numeric)
        default:
            throw UnfitExprError(expr: rhs, val: r, op: .numeric)
        }
    }

    func call(_ head: LocationExprP, _ args: ValueExprP) throws -> Any {
        func normalizeArgs() throws -> [Any] {
            let a = try eval(args)
            if let a = a as? [Any] { return a }
            return [a]
        }
        let a = try normalizeArgs()
        let h = try get(head)

        switch h {
        case let swiftFun as () throws -> Void:
            try swiftFun()
            return Rockstar.null
        case let swiftFun as ([Any]) throws -> Void:
            try swiftFun(a)
            return Rockstar.null
        case let swiftFun as () throws -> Any:
            return try swiftFun()
        case let swiftFun as () throws -> Any?:
            return try swiftFun() ?? Rockstar.null
        case let swiftFun as ([Any]) throws -> Any:
            return try swiftFun(a)
        case let swiftFun as ([Any]) throws -> Any?:
            return try swiftFun(a) ?? Rockstar.null
        case let rockFun as RockFunEvalContext:
            return try rockFun.call(argVals: a, callPos: head.range.start)
        default:
            throw UnfitExprError(expr: head, val: h, op: .call)
        }
    }

    func evalPop(_ expr: LocationExprP) throws -> Any {
        let source = try _get(expr)
        switch source {
        case var arr as RockstarArray:
            let val = arr.pop()
            try set(expr, arr)
            return val
        default:
            try set(expr, Rockstar.null)
            return source
        }
    }

    func evalPop(_ target: LocationExprP, _ source: LocationExprP) throws {
        try set(target, evalPop(source))
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
        case .pop: return try evalPop(expr.args[0] as! LocationExprP)
        case .custom: return try call(expr.args[0] as! LocationExprP, expr.args[1])
        }
    }

    func eval(_ expr: ValueExprP) throws -> Any {
        switch expr {
        case let b as LiteralExpr<Bool>:
            return b.literal
        case let n as LiteralExpr<Double>:
            return n.literal
        case let s as LiteralExpr<String>:
            return s.literal
        case let n as LiteralExpr<Rockstar.Null>:
            return n.literal
        case let m as LiteralExpr<Rockstar.Mysterious>:
            return m.literal
        case let l as LocationExprP:
            return try get(l)
        case let l as ListExpr:
            return try l.members.map{ try eval($0) }
        case let f as FunctionCallExpr:
            return try eval(f)
        default:
            assertionFailure("unhandled ValueExprP")
            return Rockstar.null
        }
    }

    func evalMath(_ opnd: ValueExprP, _ op: (Double) -> Any) throws -> Any {
        let o = try eval(opnd)
        guard let oo = o as? Double else { throw UnfitExprError(expr: opnd, val: o, op: .numeric) }
        return op(oo)
    }

    func evalPush(_ l: LocationExprP, _ arg: ValueExprP?) throws {
        func pushVal(_ arr: RockstarArray, _ val: Any) throws {
            var arr = arr
            switch val {
            case let list as [Any]:
                list.forEach{ arr.push($0) }
            default:
                arr.push(val)
            }
            try set(l, arr)
        }

        guard let arg = arg else {
            try set(l, RockstarArray())
            return
        }

        let a = try eval(arg)
        let target = try _get(l)
        switch target {
        case let arr as RockstarArray:
            try pushVal(arr, a)
        default:
            var arr = RockstarArray()
            arr[0] = target
            try pushVal(arr, a)
        }
    }

    func split(_ target: LocationExprP, _ source: ValueExprP?, _ arg: ValueExprP?) throws {
        let sourceVal = source != nil ? try eval(source!) : try _get(target)
        guard let s = sourceVal as? String else {
            throw UnfitExprError(expr: source ?? target, val: sourceVal, op: .string)
        }
        if let arg = arg {
            let a = try eval(arg)
            guard let a = a as? String else {
                throw UnfitExprError(expr: arg, val: a, op: .string)
            }
            let split = s.components(separatedBy: a)
            try set(target, RockstarArray(split))
            return
        }
        try set(target, RockstarArray(Array(s).map{ String($0) }))
    }

    func join(_ target: LocationExprP, _ source: ValueExprP?, _ arg: ValueExprP?) throws {
        let (sourceExpr, sourceVal) = try { () throws -> (ValueExprP, Any) in
            guard let source = source else {
                return try (target, _get(target))
            }
            switch source {
            case let l as LocationExprP:
                return (source, try _get(l))
            default:
                return (source, try eval(source))
            }
        }()

        guard var s = sourceVal as? RockstarArray else {
            throw UnfitExprError(expr: sourceExpr, val: sourceVal, op: .array)
        }
        guard let s = s.values() as? [String] else {
            throw UnfitExprError(expr: sourceExpr, val: sourceVal, op: .string)
        }
        if let arg = arg {
            let a = try eval(arg)
            guard let a = a as? String else {
                throw UnfitExprError(expr: arg, val: a, op: .string)
            }
            let joint = s.joined(separator: a)
            try set(target, joint)
            return
        }
        try set(target, s.joined(separator: ""))
    }

    func castDouble(_ s: String, _ arg: ValueExprP?, sourceExpr: ValueExprP) throws -> Double {
        if let a = arg {
            let argVal = try eval(a)
            guard let r = argVal as? Double else {
                throw UnfitExprError(expr: a, val: argVal, op: .castIntRadix)
            }
            guard let radix = Int(exactly: r), 2 <= r && r <= 36 else {
                throw UnfitExprError(expr: a, val: r, op: .castIntRadix)
            }
            guard let i = Int(s, radix: radix) else {
                throw UnfitExprError(expr: sourceExpr, val: s, op: .castInt)
            }
            return Double(i)
        } else {
            guard let d = Double(s) else {
                throw UnfitExprError(expr: sourceExpr, val: s, op: .castDouble)
            }
            return d
        }
    }

    func castString(_ d: Double, sourceExpr: ValueExprP) throws -> String {
        guard let i = Int(exactly: d), i >= 0 else {
            throw UnfitExprError(expr: sourceExpr, val: d, op: .castString)
        }
        guard let u = UnicodeScalar(i) else {
            throw UnfitExprError(expr: sourceExpr, val: i, op: .castString)
        }
        return String(u)
    }

    func cast(_ target: LocationExprP, _ source: ValueExprP?, _ arg: ValueExprP?) throws {
        let sourceVal = source != nil ? try eval(source!) : try _get(target)
        switch sourceVal {
        case let s as String:
            try set(target, castDouble(s, arg, sourceExpr: source ?? target))
        case let d as Double:
            try set(target, castString(d, sourceExpr: source ?? target))
        default:
            throw UnfitExprError(expr: source ?? target, val: sourceVal, op: .cast)
        }
    }

    func eval(_ expr: VoidCallExpr) throws {
        switch expr.head {
        case .assign: try set(expr.target!, try eval(expr.source!))
        case .print:  try shout(eval(expr.source!))
        case .scan:   try set(expr.target!, listen())
        case .push:   try evalPush(expr.target!, expr.arg)
        case .pop:    try evalPop(expr.target!, expr.source! as! LocationExprP)
        case .split:  try split(expr.target!, expr.source, expr.arg)
        case .join:   try join(expr.target!, expr.source, expr.arg)
        case .cast:   try cast(expr.target!, expr.source, expr.arg)
        case .ceil:   try set(expr.target!, evalMath(expr.source!, { ceil($0) }))
        case .floor:  try set(expr.target!, evalMath(expr.source!, { floor($0) }))
        case .round:  try set(expr.target!, evalMath(expr.source!, { round($0) }))
        }
    }

    func _eval(_ expr: ExprP) throws {
        switch expr {
        case let v as VoidCallExpr:
            try eval(v)
        case let c as ConditionalExpr:
            let cc = ConditionalEvalContext(parent: self)
            try cc.eval(c)
        case let l as LoopExpr:
            let lc = LoopEvalContext(parent: self)
            try lc.eval(l)
        case let f as FunctionCallExpr:
            _ = try eval(f)
        case let f as FunctionDeclExpr:
            try set(f.head, RockFunEvalContext(parent: self, argNames: f.args.map { $0.name }, f.funBlock))
        case let r as ReturnExpr:
            try doReturn(r)
        case let e as ElseExpr:
            throw StrayExprError(expr: e)
        case let b as BreakExpr:
            try doBreak(b)
        case let c as ContinueExpr:
            try doContinue(c)
        case let v as ValueExprP:
            _ = try eval(v)
        case is NopExpr:
            break
        default:
            assertionFailure("unhandled ExprP")
        }
    }
}

class MainEvalContext: EvalContext {
    var variables = [String: Any]()
    var lastVariable: String? = nil
    let debuggingSettings: DebuggingSettings

    var _exprs: AnySequence<ExprP>.Iterator
    var _listen: () throws -> Any
    var _shout: (Any) throws -> Void

    init(input inp: AnySequence<ExprP>, debuggingSettings d: DebuggingSettings, rockin: @escaping Rockin, rockout: @escaping Rockout) {
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

    func swiftify(_ v: Any) -> Any {
        switch v {
        case let d as Double:
            if let i = Int(exactly: d) {
                return i
            }
            return d
        case let r as RockstarArray:
            return r.dict
        default:
            return v
        }
    }

    func shout(_ v: Any) throws {
        try _shout(swiftify(v))
    }

    func rockify(_ v: Any) -> Any {
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
        var loopCounter = debuggingSettings.maxLoopRecursions
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

    var returnValue: Any? = nil

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
        for (a,v) in zip(argNames, argVals) {
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
