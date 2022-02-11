internal protocol Lexeme {}

internal protocol StringLexeme: Lexeme {
    var string_rep: String { get set }
    mutating func push(_ c: Character)
}

internal extension StringLexeme {
    mutating func push(_ c: Character) {
        string_rep.append(c)
    }
}

private struct NewlineLex: Lexeme {}
private struct WhitespaceLex: Lexeme {}
private struct CommentLex: StringLexeme {
    var string_rep: String = ""
}
private struct StringLex: StringLexeme {
    var string_rep: String = ""
}
private struct WordLex: StringLexeme {
    var string_rep: String = ""
}
internal struct NumberLex: StringLexeme {
    var string_rep: String = ""
    var float_rep: Float {
        return Float(string_rep)!
    }
}

private struct StringFifo {
    private var intern: String
    init(_ s: String) {
        intern = String(s.reversed())
    }
    mutating func pop() -> Character? {
        intern.popLast()
    }
    func peek() -> Character? {
        intern.last
    }
}

private func lex_comment(_ lexemes: inout [Lexeme], _ chars: inout StringFifo) {
    var depth = 0
    var comment = CommentLex()

    while let c = chars.pop() {
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

private func lex_string(_ lexemes: inout [Lexeme], _ chars: inout StringFifo) {
    var string = StringLex()

    while let c = chars.pop() {
        if c == "\\" {
            string.push(c)
            string.push(chars.pop()!)
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

private func lex_whitespace(_ lexemes: inout [Lexeme], _ chars: inout StringFifo) {
    while chars.peek()?.isWhitespace ?? false {
        _ = chars.pop()
    }
    lexemes.append(WhitespaceLex())
}

private func lex_word(firstChar: Character, _ lexemes: inout [Lexeme], _ chars: inout StringFifo) {
    var word = WordLex()
    word.push(firstChar)
    while chars.peek()?.isLetter ?? false {
        word.push(chars.pop()!)
    }
    lexemes.append(word)
}

private func lex_number(firstChar: Character, _ lexemes: inout [Lexeme], _ chars: inout StringFifo) {
    var num = NumberLex()
    num.push(firstChar)

    var accept_decimal_point = firstChar != "."
    var accept_exp = firstChar.isNumber
    var accept_sign = false

    while let c = chars.peek() {
        if c.isNumber {
            accept_exp = true
            accept_sign = false
        } else if accept_decimal_point && c == "." {
            accept_decimal_point = false
            accept_exp = false
        } else if accept_exp && c.lowercased() == "e" {
           accept_decimal_point = false
           accept_sign = true
           accept_exp = false
        } else if accept_sign && (c == "-" || c == "+") {
           accept_sign = false
        } else {
           break
        }

        num.push(c)
        _ = chars.pop()
    }

    lexemes.append(num)
}

internal func lex(_ inp: String) -> [Lexeme] {
    var lexemes: [Lexeme] = []
    var chars = StringFifo(inp)

    while let c = chars.pop() {
        if c == "(" {
            lex_comment(&lexemes, &chars)
        } else if c == "\"" {
            lex_string(&lexemes, &chars)
        } else if c == "\r" {
            continue
        } else if c == "\n" || c == "\r\n" {
            lex_newline(&lexemes)
        } else if c.isWhitespace {
            lex_whitespace(&lexemes, &chars)
        } else if c.isLetter {
            lex_word(firstChar: c, &lexemes, &chars)
        } else if c.isNumber || c == "+" || c == "-" || c == "." {
            lex_number(firstChar: c, &lexemes, &chars)
        } else {
            assertionFailure("Found unlexable chars at end of inp")
        }
    }

    return lexemes
}
