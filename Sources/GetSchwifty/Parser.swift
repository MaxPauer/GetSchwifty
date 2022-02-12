internal protocol Expr {}

internal struct Parser {
    var lines: UInt = 1

    init(lexemes: [Lexeme]) {
        var lexs = Fifo<[Lexeme]>(lexemes)

        while let l = lexs.pop() {
            switch l {
            case is NewlineLex:
                lines += 1
            case let c as CommentLex:
                lines += c.lines
            default:
                continue
            }
        }
    }
}
