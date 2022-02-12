internal protocol Expr {
    var newLines: UInt { get }
}

internal protocol VariableName: Expr {
    var name: String { get }
}

internal struct CommonVariableName: VariableName {
    var name: String
    var newLines: UInt { 0 }
}

internal struct Newline: Expr {
    var newLines: UInt { 1 }
}

internal struct Comment: Expr {
    var newLines: UInt
}

typealias Lexemes = Fifo<[Lexeme]>

internal struct Parser {
    var lines: UInt = 1
    var exprs: [Expr] = []

    func drop_whitespace(_ lexemes: inout Lexemes) throws {
        guard let next = lexemes.pop() else {
            throw UnexpectedEOFError(expected: Lexeme.whitespace)
        }
        guard next == .whitespace else {
            throw UnexpectedLexemeError(got: next, expected: Lexeme.whitespace)
        }
    }

    func parse_common_variable(_ lexemes: inout Lexemes, firstWord: String) throws -> Expr {
        try drop_whitespace(&lexemes)

        guard let sw = lexemes.pop() else {
            throw UnexpectedEOFError(expected: AnyLexeme.word)
        }
        guard case .word(let secWord) = sw else {
            throw UnexpectedLexemeError(got: sw, expected: AnyLexeme.word)
        }

        let secondWord = secWord.lowercased()
        return CommonVariableName(name: "\(firstWord) \(secondWord)")
    }

    func parse_word(_ lexemes: inout Lexemes, firstWord: String) throws -> Expr? {
        let first = firstWord.lowercased()
        switch first {
        case "a", "an", "the", "my", "your", "our":
            return try parse_common_variable(&lexemes, firstWord: first)
        default:
            //TODO: replace with throw "UnparsableWordError(word: firstWord)"
            return try next_expr(&lexemes)
        }
    }

    func next_expr(_ lexemes: inout Lexemes) throws -> Expr? {
        guard let l = lexemes.pop() else { return nil }

        switch l {
        case .newline:
            return Newline()
        case .comment(_, let l):
            return Comment(newLines: l)
        case .word(let w):
            return try parse_word(&lexemes, firstWord: w)
        default:
            // TODO: handle all and remove:
            return try next_expr(&lexemes)
        }
    }

    init(lexemes: [Lexeme]) throws {
        var lexs = Lexemes(lexemes)
        var expr: Expr?

        while true {
            do {
                expr = try next_expr(&lexs)
            } catch let err as PartialParserError {
                throw ParserError(onLine: lines, partialErr: err)
            } catch {
                assertionFailure("unexpected Error")
            }

            guard let e = expr else { break }
            lines += e.newLines
            exprs.append(e)
        }
    }
}
