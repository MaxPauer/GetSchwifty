typealias Lexemes = Fifo<[Lex]>

internal struct Parser {
    var lines: UInt = 1
    var rootExpr = RootExpr()

    func dropWhitespace(_ lexemes: inout Lexemes) throws {
        guard let next = lexemes.pop() else {
            throw UnexpectedEOFError(expected: WhitespaceLex.self)
        }
        guard next is WhitespaceLex else {
            throw UnexpectedLexemeError(got: next, expected: WhitespaceLex.self)
        }
    }

    func parseCommonVariable(_ lexemes: inout Lexemes, firstWord: String) throws -> VariableNameExpr {
        try dropWhitespace(&lexemes)

        guard let sw = lexemes.pop() else {
            throw UnexpectedEOFError(expected: IdentifierLex.self)
        }
        guard let secWord = sw as? IdentifierLex else {
            throw UnexpectedLexemeError(got: sw, expected: IdentifierLex.self)
        }

        let secondWord = secWord.literal.lowercased()
        return CommonVariableNameExpr(name: "\(firstWord) \(secondWord)")
    }

    func parsePoeticNumber(_ lexemes: inout Lexemes) throws -> ValueExpr {
        try dropWhitespace(&lexemes)
        var words: [String] = []
        let mayEnd = { words.count > 0 }
        let verifyEnd = {
            guard mayEnd() else {
                throw UnexpectedEOFError(expected: IdentifierLex.self)
            }
        }

        lexing: while true {
            if lexemes.peek() == nil {
                try verifyEnd()
                break lexing
            }
            let lex = lexemes.peek()!
            switch lex {
            case is NewlineLex:
                try verifyEnd()
                break lexing
            case is WhitespaceLex, is CommentLex:
                break // nop
            case let id as IdentifierLex:
                words.append(id.literal)
            default:
                throw UnexpectedLexemeError(got: lex, expected: IdentifierLex.self) // also whitespace, comment, and maybe newline
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
            case is NewlineLex:
                break lexing
            case is WhitespaceLex:
                string += " "
            case is CommentLex:
                break // nop
            case let id as IdentifierLex:
                string += id.literal
            // case .apostrophe: // TODO
            //     string += "'"
            case is DelimiterLex:
                string += "," // TODO: or &
            case let num as NumberLex:
                string += "\(num.value)" // TODO: original formatting
            case let str as StringLex:
                string += "\"\(str.literal)\""
            default:
                assertionFailure("unexpected lexeme")
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
        case is NewlineLex:
            return NewlineExpr()
        case let c as CommentLex:
            return CommentExpr(newLines: c.newLines)
        case let id as IdentifierLex:
            return try parseWord(&lexemes, firstWord: id.literal)
        default:
            // TODO: handle all and remove:
            return try nextExpr(&lexemes)
        }
    }

    init(lexemes: [Lex]) throws {
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
