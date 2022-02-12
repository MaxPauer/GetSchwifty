internal protocol Expr {}

internal protocol VariableName: Expr {
    var name: String { get }
}

internal struct CommonVariableName: VariableName {
    var name: String
}

typealias Lexemes = Fifo<[Lexeme]>
extension String: Error {}

internal struct Parser {
    var lines: UInt = 1
    var exprs: [Expr] = []

    func parse_common_variable(_ lexemes: inout Lexemes, firstWord: String) throws -> Expr {
        guard let ws = lexemes.pop() else {
            throw "UnexpectedEOFError(expected: .whitespace)"
        }
        guard ws == .whitespace else {
            throw "UnexpectedLexemeError(ws, expected: .whitespace)"
        }

        guard let sw = lexemes.pop() else {
            throw "UnexpectedEOFError(expected: .word)"
        }
        guard case .word(let secWord) = sw else {
            throw "UnexpectedLexemeError(sw, expected: .word)"
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
            //throw "UnparsableWordError(word: firstWord)"
            return nil
        }
    }

    init(lexemes: [Lexeme]) {
        var lexs = Lexemes(lexemes)

        while let l = lexs.pop() {
            switch l {
            case .newline:
                lines += 1
            case .comment(_, let l):
                lines += l
            case .word(let w):
                if let e = try? parse_word(&lexs, firstWord: w) {
                    exprs.append(e)
                }
            default:
                continue
            }
        }
    }
}
