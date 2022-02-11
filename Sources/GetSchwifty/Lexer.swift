internal protocol Lexeme {}

internal protocol StringLexeme: Lexeme {
    var string_rep: String { get set }
    mutating func push(_ c: Character)
}

private extension StringLexeme {
    mutating func push(_ c: Character) {
        string_rep.append(c)
    }
}

private struct NewlineLex: Lexeme {}
private struct CommentLex: StringLexeme {
    var string_rep: String = ""
}
private struct StringLex: StringLexeme {
    var string_rep: String = ""
}

private func lex_comment(_ lexemes: inout [Lexeme], _ chars: inout String.Iterator) {
    var depth = 0
    var comment = CommentLex()

    while let c = chars.next() {
        if c == "(" {
            depth += 1
        } else if c == ")" {
            if depth == 0 {
                break
            }
            depth -= 1
        }
        comment.push(c)
    }

    lexemes.append(comment)
}

private func lex_string(_ lexemes: inout [Lexeme], _ chars: inout String.Iterator) {
    var string = StringLex()

    while let c = chars.next() {
        if c == "\\" {
            string.push(c)
            string.push(chars.next()!)
            continue
        } else if c == "\"" {
            break
        }
        string.push(c)
    }

    lexemes.append(string)
}

private func lex_newline(_ lexemes: inout [Lexeme]) {
    lexemes.append(NewlineLex())
}

internal func lex(_ inp: String) -> [Lexeme] {
    var lexemes: [Lexeme] = []
    var chars = inp.makeIterator()

    while let c = chars.next() {
        if c == "(" {
            lex_comment(&lexemes, &chars)
        } else if c == "\"" {
            lex_string(&lexemes, &chars)
        } else if c == "\r" {
            continue
        } else if c == "\n" || c == "\r\n" {
            lex_newline(&lexemes)
        } else {
            assertionFailure("Found unlexable chars at end of inp")
        }
    }

    return lexemes
}
