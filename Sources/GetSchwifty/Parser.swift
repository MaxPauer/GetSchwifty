internal protocol Expr {}

internal struct Parser {
    var lines: UInt = 1

    init(lexemes: [Lexeme]) {
        var lexs = Fifo<[Lexeme]>(lexemes)

        while let l = lexs.pop() {
            switch l {
            case .newline:
                lines += 1
            case .comment(_, let l):
                lines += l
            default:
                continue
            }
        }
    }
}
