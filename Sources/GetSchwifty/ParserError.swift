internal protocol PartialParserError: Error, CustomStringConvertible {}

public struct ParserError: Error, CustomStringConvertible {
    let onLine: UInt
    let partialErr: PartialParserError

    public var description: String {
        "Parser error in expression starting on line \(onLine): \(partialErr)"
    }
}

internal struct UnexpectedEOFError: PartialParserError {
    let expected: Lexemeish

    var description: String {
        "encountered end of file while expecting: \(expected)"
    }
}

internal struct UnexpectedLexemeError: PartialParserError {
    let got: Lexeme
    let expected: Lexemeish

    var description: String {
        "encountered lexeme: \(got) while expecting: \(expected)"
    }
}

internal struct NotImplementedError: PartialParserError, Equatable {
    var description: String = "This has not been implemented 🤷‍♀️"
}
