internal protocol PartialParserError: Error, CustomStringConvertible {}

internal enum AnyLexeme: Lexemeish, Equatable {
    case comment
    case string
    case word
    case number
}

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
        "Unexpected end of file. Expecting: \(expected)"
    }
}

internal struct UnexpectedLexemeError: PartialParserError {
    let got: Lexeme
    let expected: Lexemeish

    var description: String {
        "Unexpected lexeme encountered: \(got). Expecting: \(expected)"
    }
}
