internal protocol Expr {
    var newLines: UInt { get }
    var isFinished: Bool { get }
    mutating func append(_ nextExpr: Expr) throws -> Expr
}

internal protocol VariableNameExpr: Expr {
    var name: String { get }
}

extension VariableNameExpr {
    mutating func append(_ nextExpr: Expr) throws -> Expr {
        switch nextExpr {
        case var e as AssignmentExpr:
            e.lhs = self
            return e
        default:
            throw UnexpectedExprError(got: nextExpr, expected: AssignmentExpr.self) // possibly others
        }
    }
}

internal struct CommonVariableNameExpr: VariableNameExpr {
    var name: String
    let newLines: UInt = 0
    let isFinished: Bool = false
}

internal enum ValueExpr: Expr {
    case string(String)
    case number(Float)

    var newLines: UInt { 0 }
    var isFinished: Bool { true }

    mutating func append(_ nextExpr: Expr) throws -> Expr {
        assertionFailure("appending to finished ValueExpr")
        return self
    }
}

internal struct AssignmentExpr: Expr {
    var newLines: UInt = 0
    var isFinished: Bool {
        lhs != nil && rhs != nil
    }
    var lhs: VariableNameExpr?
    var rhs: ValueExpr?

    @discardableResult
    mutating func append(_ nextExpr: Expr) throws -> Expr {
        assert(rhs == nil, "appending to finished AssignmentExpr")
        guard let expr = nextExpr as? ValueExpr else {
            throw UnexpectedExprError(got: nextExpr, expected: ValueExpr.self)
        }
        rhs = expr
        return self
    }
}

internal struct NewlineExpr: Expr {
    let newLines: UInt = 1
    let isFinished: Bool = false

    mutating func append(_ nextExpr: Expr) throws -> Expr {
        throw NotImplementedError()
    }
}

internal struct CommentExpr: Expr {
    var newLines: UInt
    let isFinished: Bool = false

    mutating func append(_ nextExpr: Expr) throws -> Expr {
        throw NotImplementedError()
    }
}

internal struct RootExpr: Expr {
    let isFinished: Bool = false
    let newLines: UInt = 0
    var children: [Expr] = []

    @discardableResult
    mutating func append(_ nextExpr: Expr) throws -> Expr {
        guard var lastExpr = children.last else {
            children.append(nextExpr)
            return self
        }
        if lastExpr.isFinished {
            children.append(nextExpr)
        } else {
            _ = children.popLast()!
            children.append(try lastExpr.append(nextExpr))
        }
        return self
    }
}

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

        while true {
            if lexemes.peek() == nil {
                try verifyEnd()
                break
            }
            let lex = lexemes.peek()!
            switch lex {
            case .whitespace:
                lexemes.drop()
                continue
            case .newline:
                try verifyEnd()
                break
            case .word(let w):
                lexemes.drop()
                words.append(w)
            default:
                throw UnexpectedLexemeError(got: lex, expected: AnyLexeme.word) // also whitespace and maybe newline
            }
        }

        var number = 0
        for w in words {
            number *= 10
            number += (w.count % 10)
        }

        return .number(Float(number))
    }

    func parsePoeticNumberAssignmentExpr(_ lexemes: inout Lexemes) throws -> AssignmentExpr {
        var a = AssignmentExpr()
        try a.append(parsePoeticNumber(&lexemes))
        return a
    }

    func parseWord(_ lexemes: inout Lexemes, firstWord: String) throws -> Expr? {
        let first = firstWord.lowercased()
        switch first {
        case "a", "an", "the", "my", "your", "our":
            return try parseCommonVariable(&lexemes, firstWord: first)
        case "is", "are", "was", "were":
            return try parsePoeticNumberAssignmentExpr(&lexemes)
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
