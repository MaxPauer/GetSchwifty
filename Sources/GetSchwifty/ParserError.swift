internal protocol ParserError: Error, CustomStringConvertible {
    var _description: String { get }
    var parsing: ExprBuilder { get }
    var startPos: LexPos { get }
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
            "<\($0)>"
        }.joined(separator: " or ")
    }

    var _description: String {
        "encountered unexpected lexeme: \(got) while parsing: \(parsing). Expecting \(expectingDescr)"
    }
}

internal struct UnexpectedLexemeError: LexemeError {
    let got: Lex
    let parsing: ExprBuilder

    var _description: String {
        "encountered unexpected lexeme: \(got) while parsing: \(parsing)"
    }
}

internal struct UnparsableNumberLexemeError: LexemeError {
    let got: Lex
    let parsing: ExprBuilder

    var _description: String {
        "encountered unparsable number lexeme: \(got) while parsing: \(parsing)"
    }
}

internal struct UnexpectedExprError<Expecting>: ParserError {
    let got: ExprP
    let startPos: LexPos
    let parsing: ExprBuilder

    var _description: String {
        "encountered unexpected expression: \(got) while parsing: \(parsing), expecting: \(Expecting.self)"
    }
}

internal struct UnexpectedEOLError: ParserError {
    let startPos: LexPos
    let parsing: ExprBuilder

    var _description: String {
        "encountered unexpected EOL while parsing: \(parsing)"
    }
}
