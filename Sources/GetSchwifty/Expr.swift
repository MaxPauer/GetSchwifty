internal protocol Expr {
    var newLines: UInt { get }
    var isFinished: Bool { get }
    mutating func append(_ nextExpr: Expr) throws -> Expr
}

internal protocol VariableNameExpr: Expr {
    var name: String { get }
}

extension VariableNameExpr {
    mutating func append(_ nextExpr: Expr) throws -> Expr {
        switch nextExpr {
        case var e as AssignmentExpr:
            e.lhs = self
            return e
        default:
            throw UnexpectedExprError(got: nextExpr, expected: AssignmentExpr.self) // possibly others
        }
    }
}

internal struct CommonVariableNameExpr: VariableNameExpr {
    var name: String
    let newLines: UInt = 0
    let isFinished: Bool = false
}

internal enum ValueExpr: Expr {
    case string(String)
    case number(Float)

    var newLines: UInt { 0 }
    var isFinished: Bool { true }

    mutating func append(_ nextExpr: Expr) throws -> Expr {
        assertionFailure("appending to finished ValueExpr")
        return self
    }
}

internal struct AssignmentExpr: Expr {
    var newLines: UInt = 0
    var lhs: VariableNameExpr?
    var rhs: ValueExpr?

    var isFinished: Bool {
        lhs != nil && rhs != nil
    }

    @discardableResult
    mutating func append(_ nextExpr: Expr) throws -> Expr {
        assert(rhs == nil, "appending to finished AssignmentExpr")
        guard let expr = nextExpr as? ValueExpr else {
            throw UnexpectedExprError(got: nextExpr, expected: ValueExpr.self)
        }
        rhs = expr
        return self
    }
}

internal struct NewlineExpr: Expr {
    let newLines: UInt = 1
    let isFinished: Bool = false

    mutating func append(_ nextExpr: Expr) throws -> Expr {
        throw NotImplementedError()
    }
}

internal struct CommentExpr: Expr {
    var newLines: UInt
    let isFinished: Bool = false

    mutating func append(_ nextExpr: Expr) throws -> Expr {
        throw NotImplementedError()
    }
}

internal struct RootExpr: Expr {
    let isFinished: Bool = false
    let newLines: UInt = 0
    var children: [Expr] = []

    @discardableResult
    mutating func append(_ nextExpr: Expr) throws -> Expr {
        guard var lastExpr = children.last else {
            children.append(nextExpr)
            return self
        }
        if lastExpr.isFinished {
            children.append(nextExpr)
        } else {
            _ = children.popLast()!
            children.append(try lastExpr.append(nextExpr))
        }
        return self
    }
}
