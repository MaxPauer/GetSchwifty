internal protocol Expr {
    var newLines: UInt { get }
    var isFinished: Bool { get }
    mutating func append(_ nextExpr: Expr) throws -> Expr
}

internal struct VariableNameExpr: Expr {
    var name: String
    let newLines: UInt = 0
    let isFinished: Bool = false

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

internal struct AssignmentExpr: Expr {
    var newLines: UInt = 0
    var lhs: VariableNameExpr?
    var rhs: Expr?

    private(set) var isFinished: Bool = false

    @discardableResult
    mutating func append(_ nextExpr: Expr) throws -> Expr {
        if nextExpr is NewlineExpr {
            isFinished = true
        } else if rhs == nil {
            rhs = nextExpr
        } else {
            try rhs = rhs!.append(nextExpr)
        }
        return self
    }
}

internal struct InputExpr: Expr {
    var newLines: UInt = 0
    var rhs: Expr?

    private(set) var isFinished: Bool = false

    @discardableResult
    mutating func append(_ nextExpr: Expr) throws -> Expr {
        if nextExpr is NewlineExpr {
            isFinished = true
        } else if rhs == nil {
            rhs = nextExpr
        } else {
            try rhs = rhs!.append(nextExpr)
        }
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

internal protocol LeafExpr: Expr {
    associatedtype LiteralType
    var literal: LiteralType { get }
}

extension LeafExpr {
    mutating func append(_ nextExpr: Expr) throws -> Expr {
        assertionFailure("trying to append to LeafExpr")
        return self
    }
}

internal struct StringExpr: LeafExpr {
    let newLines: UInt = 0
    let isFinished: Bool = false
    let literal: String
}

internal struct NumberExpr: LeafExpr {
    let newLines: UInt = 0
    let isFinished: Bool = false
    let literal: Float
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
