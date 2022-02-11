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

private struct NewlineLex: Lexeme {
    init(_ lexemes: inout [Lexeme]) {
        lexemes.append(self)
    }
}

private struct WhitespaceLex: Lexeme {
    init(_ lexemes: inout [Lexeme], _ chars: inout StringFifo) {
        while chars.peek()?.isWhitespace ?? false {
            _ = chars.pop()
        }
        lexemes.append(self)
    }
}

private struct DelimiterLex: Lexeme {
    init(_ lexemes: inout [Lexeme]) {
        lexemes.append(self)
    }
}

private struct CommentLex: StringLexeme {
    var string_rep: String = ""

    init(_ lexemes: inout [Lexeme], _ chars: inout StringFifo) {
        var depth = 0

        while let c = chars.pop() {
            if c == "(" {
                depth += 1
            } else if c == ")" {
                if depth == 0 {
                    break
                }
                depth -= 1
            }
            self.push(c)
        }

        lexemes.append(self)
    }
}

private struct StringLex: StringLexeme {
    var string_rep: String = ""
    init(_ lexemes: inout [Lexeme], _ chars: inout StringFifo) {
        while let c = chars.pop() {
            if c == "\\" {
                self.push(c)
                self.push(chars.pop()!)
                continue
            } else if c == "\"" {
                break
            }
            self.push(c)
        }

        lexemes.append(self)
    }
}

private struct WordLex: StringLexeme {
    var string_rep: String = ""

    init(firstChar: Character, _ lexemes: inout [Lexeme], _ chars: inout StringFifo) {
        self.push(firstChar)
        while chars.peek()?.isLetter ?? false {
            self.push(chars.pop()!)
        }
        lexemes.append(self)
    }
}

internal struct NumberLex: StringLexeme {
    var string_rep: String = ""
    var float_rep: Float {
        return Float(string_rep)!
    }

    fileprivate init(firstChar: Character, _ lexemes: inout [Lexeme], _ chars: inout StringFifo) {
        self.push(firstChar)

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

            self.push(c)
            _ = chars.pop()
        }

        lexemes.append(self)
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

internal func lex(_ inp: String) -> [Lexeme] {
    var lexemes: [Lexeme] = []
    var chars = StringFifo(inp)

    while let c = chars.pop() {
        if c == "(" {
            CommentLex(&lexemes, &chars)
        } else if c == "\"" {
            StringLex(&lexemes, &chars)
        } else if c == "\r" {
            continue
        } else if c == "\n" || c == "\r\n" {
            NewlineLex(&lexemes)
        } else if c.isWhitespace {
            WhitespaceLex(&lexemes, &chars)
        } else if c.isLetter {
            WordLex(firstChar: c, &lexemes, &chars)
        } else if c.isNumber || c == "+" || c == "-" || c == "." {
            NumberLex(firstChar: c, &lexemes, &chars)
        } else if c == "," || c == "&" {
            DelimiterLex(&lexemes)
        } else {
            assertionFailure("Found unlexable chars at end of inp")
        }
    }

    return lexemes
}
