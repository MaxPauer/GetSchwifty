internal protocol EvalContext {
    var variables: [String: Any] { get set }
}

extension EvalContext {
    subscript(_ i: LocationExprP) -> Any? {
        set {
            switch i {
            case let v as VariableNameExpr:
                variables[v.name] = newValue
            case _ as PronounExpr:
                return // TODO
            case _ as IndexingExpr:
                return // TODO
            default:
                assertionFailure("unhandled LocationExprP")
            }
        } get {
            switch i {
            case let v as VariableNameExpr:
                return variables[v.name]
            case _ as PronounExpr:
                return nil // TODO
            case _ as IndexingExpr:
                return nil // TODO
            default:
                assertionFailure("unhandled LocationExprP")
                return nil
            }
        }
    }

    func eval<T>(_ expr: T)-> T.LiteralT where T: LiteralExprP {
        expr.literal
    }

    func eval(_ expr: ValueExprP) -> Any? {
        switch expr {
        case let b as BoolExpr:
            let bb: Bool = eval(b)
            return bb
        case let l as LocationExprP:
            return self[l]
        default: // TODO
            assertionFailure("unhandled ValueExprP")
            return nil
        }
    }

    mutating func eval(_ expr: VoidCallExpr) throws {
        switch expr.head {
        case .assign: self[expr.target!] = eval(expr.source!)
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
        case _ as FunctionCallExpr:
            break // TODO
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
