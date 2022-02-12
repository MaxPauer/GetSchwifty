typealias Lexemes = Fifo<[Lexeme]>

internal struct Parser {
    var lines: UInt = 1
    var rootExpr = RootExpr()

    func dropWhitespace(_ lexemes: inout Lexemes) throws {
        guard let next = lexemes.pop() else {
            throw UnexpectedEOFError(expected: Lexeme.whitespace)
        }
        guard next == .whitespace else {
            throw UnexpectedLexemeError(got: next, expected: Lexeme.whitespace)
        }
    }

    func parseCommonVariable(_ lexemes: inout Lexemes, firstWord: String) throws -> VariableNameExpr {
        try dropWhitespace(&lexemes)

        guard let sw = lexemes.pop() else {
            throw UnexpectedEOFError(expected: AnyLexeme.word)
        }
        guard case .word(let secWord) = sw else {
            throw UnexpectedLexemeError(got: sw, expected: AnyLexeme.word)
        }

        let secondWord = secWord.lowercased()
        return CommonVariableNameExpr(name: "\(firstWord) \(secondWord)")
    }

    func parsePoeticNumber(_ lexemes: inout Lexemes) throws -> ValueExpr {
        try dropWhitespace(&lexemes)
        var words: [String] = []
        let mayEnd = { words.count > 0 }
        let verifyEnd = {
            guard mayEnd() else {
                throw UnexpectedEOFError(expected: AnyLexeme.word)
            }
        }

        lexing: while true {
            if lexemes.peek() == nil {
                try verifyEnd()
                break lexing
            }
            let lex = lexemes.peek()!
            switch lex {
            case .newline:
                try verifyEnd()
                break lexing
            case .whitespace, .comment:
                break // nop
            case .word(let w):
                words.append(w)
            default:
                throw UnexpectedLexemeError(got: lex, expected: AnyLexeme.word) // also whitespace, comment, and maybe newline
            }

            lexemes.drop()
        }

        var number = 0
        for w in words {
            number *= 10
            number += (w.count % 10)
        }

        return .number(Float(number))
    }

    func parsePoeticString(_ lexemes: inout Lexemes) throws -> ValueExpr {
        try dropWhitespace(&lexemes)
        var string = ""

        lexing: while let lex = lexemes.peek() {
            switch lex {
            case .newline:
                break lexing
            case .whitespace:
                string += " "
            case .comment:
                break // nop
            case .word(let w):
                string += w
            // case .apostrophe: // TODO
            //     string += "'"
            case .delimiter:
                string += "," // TODO: or &
            case .number(let f):
                string += "\(f)" // TODO: original formatting
            case .string(let s):
                string += "\"\(s)\""
            }

            lexemes.drop()
        }

        return .string(string)
    }

    func parsePoeticNumberAssignmentExpr(_ lexemes: inout Lexemes) throws -> AssignmentExpr {
        var a = AssignmentExpr()
        try a.append(parsePoeticNumber(&lexemes))
        return a
    }

    func parsePoeticStringAssignmentExpr(_ lexemes: inout Lexemes) throws -> AssignmentExpr {
        var a = AssignmentExpr()
        try a.append(parsePoeticString(&lexemes))
        return a
    }

    func parseWord(_ lexemes: inout Lexemes, firstWord: String) throws -> Expr? {
        let first = firstWord.lowercased()
        switch first {
        case "a", "an", "the", "my", "your", "our":
            return try parseCommonVariable(&lexemes, firstWord: first)
        case "is", "are", "was", "were":
            return try parsePoeticNumberAssignmentExpr(&lexemes)
        case "say", "says", "said":
            return try parsePoeticStringAssignmentExpr(&lexemes)
        default:
            //TODO: replace with throw "UnparsableWordError(word: firstWord)"
            return try nextExpr(&lexemes)
        }
    }

    func nextExpr(_ lexemes: inout Lexemes) throws -> Expr? {
        guard let l = lexemes.pop() else { return nil }

        switch l {
        case .newline:
            return NewlineExpr()
        case .comment(_, let l):
            return CommentExpr(newLines: l)
        case .word(let w):
            return try parseWord(&lexemes, firstWord: w)
        default:
            // TODO: handle all and remove:
            return try nextExpr(&lexemes)
        }
    }

    init(lexemes: [Lexeme]) throws {
        var lexs = Lexemes(lexemes)
        var expr: Expr!

        while true {
            do {
                let e = try nextExpr(&lexs)
                guard e != nil else { break }
                expr = e!
                try rootExpr.append(expr)
            } catch let err as PartialParserError {
                throw ParserError(onLine: lines, partialErr: err)
            } catch {
                assertionFailure("unexpected Error")
            }

            lines += expr.newLines
        }
    }
}
