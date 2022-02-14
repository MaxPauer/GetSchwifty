internal protocol ParserError: Error, CustomStringConvertible {
    var _description: String { get }
    var got: Lex { get }
}

extension ParserError {
    var description: String {
        let pos = got.range.start
        return "Parser error on line \(pos.line):\(pos.char): \(_description)"
    }
}

internal struct UnexpectedIdentifierError: ParserError {
    let got: Lex
    let parsing: Expr
    let expecting: Set<String>

    var expectingDescr: String {
        expecting.map {
            "\"\($0)\""
        }.joined(separator: " or ")
    }

    var _description: String {
        "encountered unexpected lexeme: \(got) while parsing: \(parsing). Expecting \(expectingDescr)"
    }
}

internal struct UnexpectedLexemeError: ParserError {
    let got: Lex
    let parsing: Expr

    var _description: String {
        "encountered unexpected lexeme: \(got) while parsing: \(parsing)"
    }
}

internal struct UnexpectedEOLError: ParserError {
    let got: Lex
    let parsing: Expr

    var _description: String {
        "encountered unexpected EOL while parsing: \(parsing)"
    }
}

internal struct NotImplementedError: ParserError {
    let got: Lex
    var _description: String = "This has not been implemented 🤷‍♀️"
}

internal struct LeafExprPushError: ParserError {
    let got: Lex
    let leafExpr: Expr

    var _description: String {
        "trying to push lexeme \(got) onto \(leafExpr)"
    }
}
