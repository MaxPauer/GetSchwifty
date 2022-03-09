internal protocol RockstarError: Error, CustomStringConvertible {
    var _description: String { get }
    var startPos: LexPos { get }
}

internal protocol ParserError: RockstarError {
    var parsing: ExprBuilder { get }
}

extension ParserError {
    var description: String {
        return "Parser error on line \(startPos.line):\(startPos.char): \(_description)"
    }
}

internal protocol LexemeError: ParserError {
    var got: Lex { get }
}

extension LexemeError {
    var startPos: LexPos { got.range.start }
}

internal struct UnexpectedIdentifierError: LexemeError {
    let got: Lex
    let parsing: ExprBuilder
    let expecting: Set<String>

    var expectingDescr: String {
        expecting.map {
            "‹\($0)›"
        }.joined(separator: " or ")
    }

    var _description: String {
        "encountered unexpected \(got) lexeme while parsing \(parsing) expression. Expecting \(expectingDescr)"
    }
}

internal struct UnexpectedLexemeError: LexemeError {
    let got: Lex
    let parsing: ExprBuilder

    var _description: String {
        "encountered unexpected \(got) lexeme while parsing \(parsing) expression"
    }
}

internal struct UnparsableNumberLexemeError: LexemeError {
    let got: Lex
    let parsing: ExprBuilder

    var _description: String {
        "encountered unparsable number \(got) lexeme while parsing \(parsing) expression"
    }
}

internal struct UnexpectedExprError<Expecting>: ParserError {
    let got: ExprP
    let startPos: LexPos
    let parsing: ExprBuilder

    var _description: String {
        "encountered unexpected \(got) expression while parsing \(parsing) expression, expecting: \(Expecting.self)"
    }
}

internal struct UnfinishedExprError: ParserError {
    var parsing: ExprBuilder
    let expecting: Set<String>

    var startPos: LexPos { parsing.range.end }

    var expectingDescr: String {
        expecting.map {
            "‹\($0)›"
        }.joined(separator: " or ")
    }

    var _description: String {
        "unfinished \(parsing) expression, expecting: \(expectingDescr)"
    }
}

internal protocol RuntimeError: RockstarError {}

extension RuntimeError {
    var description: String {
        return "Runtime error on line \(startPos.line):\(startPos.char): \(_description)"
    }
}

internal struct LocationError: RuntimeError {
    enum Op: CustomStringConvertible {
        case read
        case write
        var description: String {
            switch self {
            case .read: return "reading"
            case .write: return "writing"
            }
        }
    }
    let location: LocationExprP
    let op: Op
    var startPos: LexPos { location.range.start }
    var _description: String {
        "\(op) location \(location) before assignment"
    }
}

internal struct NonBooleanExprError: RuntimeError {
    let expr: ExprP
    var startPos: LexPos { expr.range.start }
    var _description: String {
        "expression \(expr) cannot be evaluated to Bool"
    }
}

internal struct NonEquatableExprError: RuntimeError {
    let expr: ExprP
    let val: Any
    var startPos: LexPos { expr.range.start }
    var _description: String {
        "expression \(expr), evaluated to \(val) cannot be equated"
    }
}

internal struct NonNumericExprError: RuntimeError {
    let expr: ExprP
    let val: Any
    var startPos: LexPos { expr.range.start }
    var _description: String {
        "expression \(expr), evaluated to \(val) cannot be used for numeric operations"
    }
}

internal struct NonStringExprError: RuntimeError {
    let expr: ExprP
    let val: Any
    var startPos: LexPos { expr.range.start }
    var _description: String {
        "expression \(expr), evaluated to \(val) cannot be used for String operations"
    }
}

internal struct NonArrayExprError: RuntimeError {
    let expr: ExprP
    let val: Any
    var startPos: LexPos { expr.range.start }
    var _description: String {
        "expression \(expr), evaluated to \(val) cannot be used for array operations"
    }
}


internal struct StrayExprError: RuntimeError {
    let expr: ExprP
    var startPos: LexPos { expr.range.start }
    var _description: String {
        "stray \(expr) expression"
    }
}

internal struct UncallableLocationError: RuntimeError {
    let expr: ExprP
    let val: Any
    var startPos: LexPos { expr.range.start }
    var _description: String {
        "location \(expr), evaluated to \(val) cannot be called"
    }
}

internal struct NonIndexableLocationError: RuntimeError {
    let expr: IndexingExpr
    let val: Any
    var startPos: LexPos { expr.range.start }
    var _description: String {
        "location \(expr), evaluated to \(val) cannot be indexed"
    }
}

internal struct InvalidIndexError: RuntimeError {
    let expr: IndexingExpr
    let index: Any
    var startPos: LexPos { expr.range.start }
    var _description: String {
        "location \(expr) cannot be indexed with \(index)"
    }
}
