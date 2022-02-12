internal protocol PartialParserError: Error, CustomStringConvertible {}

public struct ParserError: Error, CustomStringConvertible {
    let onLine: UInt
    let partialErr: PartialParserError

    public var description: String {
        "Parser error in expression starting on line \(onLine): \(partialErr)"
    }
}

internal struct UnexpectedEOFError: PartialParserError {
    let expected: Lex.Type

    var description: String {
        "encountered end of file while expecting: \(expected)"
    }
}

internal struct UnexpectedLexemeError: PartialParserError {
    let got: Lex
    let expected: Lex.Type

    var description: String {
        "encountered lexeme: \(got) while expecting: \(expected)"
    }
}

internal struct NotImplementedError: PartialParserError, Equatable {
    var description: String = "This has not been implemented 🤷‍♀️"
}

internal struct UnexpectedExprError: PartialParserError {
    let got: Expr
    let expected: Expr.Type

    var description: String {
        "encountered expression: \(got) while expecting: \(expected)"
    }
}
