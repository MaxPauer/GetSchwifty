public protocol RockstarError: Error, CustomStringConvertible {
    var errorPos: (line: UInt, char: UInt) { get }
}
public protocol ParserError: RockstarError {}
public protocol RuntimeError: RockstarError {}

protocol IRockstarError: RockstarError, CustomDebugStringConvertible {
    var startPos: LexPos { get }
}

extension IRockstarError {
    var errorPos: (line: UInt, char: UInt) { (line: startPos.line, char: startPos.char) }
}

protocol IParserError: IRockstarError, ParserError {
    var parsing: ExprBuilder { get }
}

protocol IRuntimeError: IRockstarError, RuntimeError {}

extension IParserError {
    var description: String {
        return "Parser error on line \(startPos.line):\(startPos.char): \(debugDescription)"
    }
}
extension IRuntimeError {
    var description: String {
        return "Runtime error on line \(startPos.line):\(startPos.char): \(debugDescription)"
    }
}

protocol ILexemeError: IParserError {
    var got: Lex { get }
}

extension ILexemeError {
    var startPos: LexPos { got.range.start }
}

protocol IExprError: IRuntimeError {
    var expr: ExprP { get }
}

extension IExprError {
    var startPos: LexPos { expr.range.start }
}

struct UnexpectedIdentifierError: ILexemeError {
    let got: Lex
    let parsing: ExprBuilder
    let expecting: Set<String>

    var expectingDescr: String {
        expecting.map {
            "‹\($0)›"
        }.joined(separator: " or ")
    }

    var debugDescription: String {
        "encountered unexpected \(got) lexeme while parsing \(parsing) expression. Expecting \(expectingDescr)"
    }
}

struct UnexpectedLexemeError: ILexemeError {
    let got: Lex
    let parsing: ExprBuilder

    var debugDescription: String {
        "encountered unexpected \(got) lexeme while parsing \(parsing) expression"
    }
}

struct UnparsableNumberLexemeError: ILexemeError {
    let got: Lex
    let parsing: ExprBuilder

    var debugDescription: String {
        "encountered unparsable number \(got) lexeme while parsing \(parsing) expression"
    }
}

struct UnexpectedExprError<Expecting>: IParserError {
    let got: ExprP
    let parsing: ExprBuilder

    var startPos: LexPos { got.range.start }

    var debugDescription: String {
        "encountered unexpected \(got) expression while parsing \(parsing) expression, expecting: \(Expecting.self)"
    }
}

struct UnfinishedExprError: IParserError {
    var parsing: ExprBuilder
    let expecting: Set<String>

    var startPos: LexPos { parsing.range.end }

    var expectingDescr: String {
        expecting.map {
            "‹\($0)›"
        }.joined(separator: " or ")
    }

    var debugDescription: String {
        "unfinished \(parsing) expression, expecting: \(expectingDescr)"
    }
}

struct LocationError: IExprError {
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
    let expr: ExprP
    let op: Op
    var debugDescription: String {
        "\(op) \(expr) before assignment"
    }
}

struct UnfitExprError: IExprError {
    enum Op: CustomStringConvertible {
        case bool; case equation
        case string; case array; case call; case index
        case cast; case castInt; case castIntRadix
        case castDouble; case castString

        var description: String {
            switch self {
            case .bool: return "boolean"
            case .equation: return "equation"
            case .string: return "string"
            case .array: return "array"
            case .call: return "function call"
            case .index: return "indexing"
            case .cast: return "casting"
            case .castInt: return "cast to int"
            case .castIntRadix: return "cast to int (radix)"
            case .castDouble: return "cast to double"
            case .castString: return "cast to string"
            }
        }
    }

    let expr: ExprP
    let val: Any
    let op: Op
    var debugDescription: String {
        "expression \(expr) evaluated to \(val) cannot be used for \(op) operations"
    }
}

struct StrayExprError: IExprError {
    let expr: ExprP
    var debugDescription: String {
        "stray \(expr) expression"
    }
}

struct InvalidIndexError: IExprError {
    let expr: ExprP
    let index: Any
    var debugDescription: String {
        "location \(expr) cannot be indexed with \(index)"
    }
}

struct InvalidArgumentCountError: IRuntimeError {
    let expecting: Int
    let got: Int
    let startPos: LexPos
    var debugDescription: String {
        "mismatching function argument count expected \(expecting), got \(got)"
    }
}

struct MaxLoopRecursionExceededError: IExprError {
    let expr: ExprP
    var debugDescription: String {
        "maximum number of loop recursions reached"
    }
}
