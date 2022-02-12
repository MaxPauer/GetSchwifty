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

internal struct NewlineLex: Lexeme {}
internal struct DelimiterLex: Lexeme {}

internal struct WhitespaceLex: Lexeme {
    fileprivate init(_ chars: inout Fifo<String>) {
        while chars.peek()?.isWhitespace ?? false {
            _ = chars.pop()
        }
    }
}

internal struct CommentLex: StringLexeme {
    var string_rep: String = ""

    fileprivate init(_ chars: inout Fifo<String>) {
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
    }
}

internal struct StringLex: StringLexeme {
    var string_rep: String = ""
    fileprivate init(_ chars: inout Fifo<String>) {
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
    }
}

internal struct WordLex: StringLexeme {
    var string_rep: String = ""

    fileprivate init(firstChar: Character, _ chars: inout Fifo<String>) {
        self.push(firstChar)
        while chars.peek()?.isLetter ?? false {
            self.push(chars.pop()!)
        }
    }
}

internal struct NumberLex: StringLexeme {
    var string_rep: String = ""
    var float_rep: Float {
        return Float(string_rep)!
    }

    fileprivate init(firstChar: Character, _ chars: inout Fifo<String>) {
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
    }
}

fileprivate func ~=<T>(pattern: KeyPath<T, Bool>, value: T) -> Bool {
    value[keyPath: pattern]
}

private func next_lexeme(_ chars: inout Fifo<String>) -> Lexeme? {
    guard let c = chars.pop() else { return nil }

    switch c {
    case "(":
        return CommentLex(&chars)
    case "\"":
        return StringLex(&chars)
    case "\r":
        return next_lexeme(&chars)
    case "\n", "\r\n":
        return NewlineLex()
    case ",", "&":
        return DelimiterLex()
    case \.isWhitespace:
        return WhitespaceLex(&chars)
    case \.isLetter:
        return WordLex(firstChar: c, &chars)
    case \.isNumber, "+", "-", ".":
        return NumberLex(firstChar: c, &chars)
    default:
        assertionFailure("Found unlexable chars at end of input")
        return nil
    }
}

internal func lex(_ inp: String) -> [Lexeme] {
    var lexemes: [Lexeme] = []
    var chars = Fifo<String>(inp)

    while let l = next_lexeme(&chars) {
        lexemes.append(l)
    }

    return lexemes
}
