typealias Lexemes = Fifo<[Lex]>

fileprivate extension String {
    var isCommonVariableIdentifier: Bool {
        let l = self.lowercased()
        return l == "a" || l == "an" || l == "the" || l == "my" || l == "your" || l == "our"
    }
    var firstCharIsUpperCase: Bool {
        return self.first!.isUppercase
    }
}

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
        return VariableNameExpr(name: "\(firstWord) \(secondWord)")
    }

    func parseProperVariable(_ lexemes: inout Lexemes, firstWord: String) throws -> VariableNameExpr {
        try dropWhitespace(&lexemes)
        var words: [String] = [firstWord]
        let mayEnd = { words.count > 1 }
        let verifyEnd = {
            guard mayEnd() else {
                throw UnexpectedEOFError(expected: IdentifierLex.self)
            }
        }

        lexing: while let lex = lexemes.peek() {
            switch lex {
            case is NewlineLex:
                break lexing
            case is WhitespaceLex, is CommentLex:
                break // nop
            case let id as IdentifierLex:
                words.append(id.literal.lowercased())
            default:
                throw UnexpectedLexemeError(got: lex, expected: IdentifierLex.self) // also whitespace, comment, and maybe newline
            }

            lexemes.drop()
        }

        try verifyEnd()
        return VariableNameExpr(name: words.joined(separator: " "))
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

        lexing: while let lex = lexemes.peek() {
            switch lex {
            case is NewlineLex:
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
        try verifyEnd()

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
            case is WhitespaceLex, is IdentifierLex, is ApostropheLex, is DelimiterLex, is NumberLex:
                string += lex.literal
            case is CommentLex:
                break // nop
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

    func parseVariable(_ lexemes: inout Lexemes) throws -> VariableNameExpr {
        try dropWhitespace(&lexemes)

        guard let lex = lexemes.pop() else {
            throw UnexpectedEOFError(expected: IdentifierLex.self)
        }
        guard let firstWord = lex as? IdentifierLex else {
            throw UnexpectedLexemeError(got: lex, expected: IdentifierLex.self)
        }

        let first = firstWord.literal
        switch first {
        case \.isCommonVariableIdentifier:
            return try parseCommonVariable(&lexemes, firstWord: first.lowercased())
        case \.firstCharIsUpperCase:
            return try parseProperVariable(&lexemes, firstWord: first.lowercased())
        default:
            throw NotImplementedError()
        }
    }

    func parseLetAssignmentExpr(_ lexemes: inout Lexemes) throws -> AssignmentExpr {
        var a = AssignmentExpr()
        a.lhs = try parseVariable(&lexemes)

        try dropWhitespace(&lexemes)

        guard let lexBe = lexemes.pop() else {
            throw UnexpectedEOFError(expected: IdentifierLex.self)
        }
        guard let beId = lexBe as? IdentifierLex else {
            throw UnexpectedLexemeError(got: lexBe, expected: IdentifierLex.self)
        }
        guard beId.literal.lowercased() == "be" else {
            throw UnexpectedLexemeError(got: lexBe, expected: IdentifierLex.self) // ("be")
        }

        try dropWhitespace(&lexemes)

        return a
    }

    func parseIdentifier(_ lexemes: inout Lexemes, firstWord: String) throws -> Expr? {
        let first = firstWord.lowercased()
        switch first {
        case \.isCommonVariableIdentifier:
            return try parseCommonVariable(&lexemes, firstWord: first)
        case "is", "are", "was", "were":
            return try parsePoeticNumberAssignmentExpr(&lexemes)
        case "say", "says", "said":
            return try parsePoeticStringAssignmentExpr(&lexemes)
        case "let":
            return try parseLetAssignmentExpr(&lexemes)
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
            return try parseIdentifier(&lexemes, firstWord: id.literal)
        case let str as StringLex:
            return ValueExpr.string(str.literal)
        case let num as NumberLex:
            return ValueExpr.number(num.value)
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
