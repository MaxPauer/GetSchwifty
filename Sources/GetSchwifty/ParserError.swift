internal protocol ParserError: Error, CustomStringConvertible {
    var _description: String { get }
    var parsing: ExprBuilder { get }
    var range: LexRange { get }
}

extension ParserError {
    var description: String {
        let pos = range.start
        return "Parser error on line \(pos.line):\(pos.char): \(_description)"
    }
}

internal protocol LexemeError: ParserError {
    var got: Lex { get }

}

extension LexemeError {
    var range: LexRange { got.range }
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
    let range: LexRange
    let parsing: ExprBuilder

    var _description: String {
        "encountered unexpected expression: \(got) while parsing: \(parsing), expecting: \(Expecting.self)"
    }
}

internal struct UnexpectedEOLError: ParserError {
    let range: LexRange
    let parsing: ExprBuilder

    var _description: String {
        "encountered unexpected EOL while parsing: \(parsing)"
    }
}

internal struct LeafExprPushError: LexemeError {
    let got: Lex
    let parsing: ExprBuilder

    var _description: String {
        "trying to push lexeme \(got) onto \(parsing)"
    }
}
