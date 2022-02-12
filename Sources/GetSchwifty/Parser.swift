internal protocol Expr {
    var newLines: UInt { get }
    var isFinished: Bool { get }
    mutating func append(_ nextExpr: Expr) throws -> Expr
}

internal protocol VariableName: Expr {
    var name: String { get }
}

internal struct CommonVariableName: VariableName {
    var name: String
    let newLines: UInt = 0
    let isFinished: Bool = false

    mutating func append(_ nextExpr: Expr) throws -> Expr {
        throw NotImplementedError()
    }
}

internal struct Newline: Expr {
    let newLines: UInt = 1
    let isFinished: Bool = false

    mutating func append(_ nextExpr: Expr) throws -> Expr {
        throw NotImplementedError()
    }
}

internal struct Comment: Expr {
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
        var expr: Expr!

        while true {
            do {
                let e = try next_expr(&lexs)
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
