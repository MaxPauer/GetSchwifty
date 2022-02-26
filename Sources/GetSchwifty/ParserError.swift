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
