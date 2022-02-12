internal enum Lexeme: Equatable {
    case newline
    case delimiter
    case whitespace
    case comment(String, UInt)
    case string(String)
    case word(String)
    case number(Float)

    init(whitespace chars: inout Fifo<String>) {
        while chars.peek()?.isWhitespace ?? false {
            _ = chars.pop()
        }
        self = .whitespace
    }

    init(comment chars: inout Fifo<String>) {
        var depth = 0
        var lines: UInt = 1
        var rep = ""

        while let c = chars.pop() {
            if c == "(" {
                depth += 1
            } else if c == ")" {
                if depth == 0 {
                    break
                }
                depth -= 1
            } else if c.isNewline {
                lines += 1
            }
            rep.append(c)
        }

        self = .comment(rep, lines)
    }

    init(string chars: inout Fifo<String>) {
        var rep = ""
        while let c = chars.pop() {
            if c == "\\" {
                rep.append(c)
                rep.append(chars.pop()!)
                continue
            } else if c == "\"" {
                break
            }
            rep.append(c)
        }
        self = .string(rep)
    }

    init(word chars: inout Fifo<String>, firstChar: Character) {
        var rep = String(firstChar)
        while chars.peek()?.isLetter ?? false {
            rep.append(chars.pop()!)
        }
        self = .word(rep)
    }

    init(number chars: inout Fifo<String>, firstChar: Character) {
        var rep = String(firstChar)

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
            rep.append(chars.pop()!)
        }

        self = .number(Float(rep)!)
    }
}

fileprivate extension Character {
    var isNewline: Bool {
        self == "\n" || self == "\r\n"
    }
}

fileprivate func ~=<T>(pattern: KeyPath<T, Bool>, value: T) -> Bool {
    value[keyPath: pattern]
}

private func next_lexeme(_ chars: inout Fifo<String>) -> Lexeme? {
    guard let c = chars.pop() else { return nil }

    switch c {
    case "(":
        return Lexeme(comment: &chars)
    case "\"":
        return Lexeme(string: &chars)
    case "\r":
        return next_lexeme(&chars)
    case \.isNewline:
        return .newline
    case ",", "&":
        return .delimiter
    case \.isWhitespace:
        return Lexeme(whitespace: &chars)
    case \.isLetter:
        return Lexeme(word: &chars, firstChar: c)
    case \.isNumber, "+", "-", ".":
        return Lexeme(number: &chars, firstChar: c)
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
