internal protocol Lexemeish {
    var prettyName: String { get }
}

internal enum AnyLexeme: Lexemeish, Equatable, CustomStringConvertible {
    case comment
    case string
    case word
    case number

    var prettyName: String {
        switch self {
        case .string: return "String"
        case .comment: return "Comment"
        case .word: return "Identifier"
        case .number: return "Number"
        }
    }

    var description: String {
        return "<\(self.prettyName)>"
    }
}

internal enum Lexeme: Lexemeish, Equatable, CustomStringConvertible {
    case newline
    case delimiter
    case whitespace
    case comment(String, UInt)
    case string(String)
    case word(String)
    case number(Float)

    var prettyName: String {
        switch self {
        case .newline: return "Newline"
        case .delimiter: return "ListDelimiter"
        case .whitespace: return "Whitespace"
        case .string: return AnyLexeme.string.prettyName
        case .comment: return AnyLexeme.comment.prettyName
        case .word: return AnyLexeme.word.prettyName
        case .number: return AnyLexeme.number.prettyName
        }
    }

    var description: String {
        let p = self.prettyName
        switch self {
        case .newline: return "<\(p)>"
        case .delimiter: return "<\(p)>"
        case .whitespace: return "<\(p)>"
        case .string(let s): return "<\(p): \"\(s)\">"
        case .comment(let c, _): return "<\(p): (\(c))>"
        case .word(let w): return "<\(p): \(w)>"
        case .number(let f): return "<\(p): \(f)>"
        }
    }

    init(whitespace chars: inout Fifo<String>) {
        while let c = chars.peek() {
            guard c.isWhitespace && !c.isNewline else { break }
            chars.drop()
        }
        self = .whitespace
    }

    init(comment chars: inout Fifo<String>) {
        var depth = 0
        var newLines: UInt = 0
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
                newLines += 1
            }
            rep.append(c)
        }

        self = .comment(rep, newLines)
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
