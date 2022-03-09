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
        case read; case write
        case readPronoun; case writePronoun

        var description: String {
            switch self {
            case .read: return "reading location"
            case .write: return "writing location"
            case .readPronoun: return "reading pronoun"
            case .writePronoun: return "writing pronoun"
            }
        }
    }
    let location: LocationExprP
    let op: Op
    var startPos: LexPos { location.range.start }
    var _description: String {
        "\(op) \(location) before assignment"
    }
}

internal struct UnfitExprError: RuntimeError {
    enum Op: CustomStringConvertible {
        case bool; case equation; case numeric
        case string; case array; case call; case index

        var description: String {
            switch self {
            case .bool: return "boolean"
            case .equation: return "equation"
            case .numeric: return "numeric"
            case .string: return "string"
            case .array: return "array"
            case .call: return "function call"
            case .index: return "indexing"
            }
        }
    }

    let expr: ExprP
    let val: Any
    let op: Op
    var startPos: LexPos { expr.range.start }
    var _description: String {
        "expression \(expr) evaluated to \(val) cannot be used for \(op) operations"
    }
}

internal struct StrayExprError: RuntimeError {
    let expr: ExprP
    var startPos: LexPos { expr.range.start }
    var _description: String {
        "stray \(expr) expression"
    }
}

internal struct InvalidIndexError: RuntimeError {
    let expr: LocationExprP
    let index: Any
    var startPos: LexPos { expr.range.start }
    var _description: String {
        "location \(expr) cannot be indexed with \(index)"
    }
}
