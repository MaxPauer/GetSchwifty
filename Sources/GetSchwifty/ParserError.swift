internal protocol PartialParserError: Error, CustomStringConvertible {}

public struct ParserError: Error, CustomStringConvertible {
    let onLine: UInt
    let partialErr: PartialParserError

    public var description: String {
        "Parser Error on line \(onLine): \(partialErr)"
    }
}

internal struct UnexpectedEOFError: PartialParserError {
    let expected: Lexeme

    var description: String {
        "Unexpected end of file. Expecting: \(expected)"
    }
}

internal struct UnexpectedLexemeError: PartialParserError {
    let got: Lexeme
    let expected: Lexeme

    var description: String {
        "Unexpected lexeme encountered: \(got). Expecting: \(expected)"
    }
}
