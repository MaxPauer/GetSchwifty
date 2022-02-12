internal protocol Lex: CustomStringConvertible {
    var prettyName: String { get }
    var useLiteralDescription: Bool { get }
    var literal: String { get }
}

extension Lex {
    var description: String {
        useLiteralDescription ? "<\(prettyName): \(literal)>" : "<\(prettyName)>"
    }
}

internal struct NewlineLex: Lex {
    let prettyName = "Newline"
    let useLiteralDescription = false
    let literal: String

    init(_ c: Character) {
        literal = String(c)
    }
}

internal struct DelimiterLex: Lex {
    var prettyName = "Delimiter"
    let useLiteralDescription = false
    let literal: String

    init(_ c: Character) {
        literal = String(c)
    }
}

internal struct ApostropheLex: Lex {
    var prettyName = "Apostrophe"
    let useLiteralDescription = false
    let literal = "'"
}

internal struct WhitespaceLex: Lex {
    var prettyName = "Whitespace"
    let useLiteralDescription = false
    let literal: String

    init(_ chars: inout Fifo<String>, firstChar: Character) {
        var l = String(firstChar)
        while let c = chars.peek() {
            guard c.isWhitespace && !c.isNewline else { break }
            l.append(chars.pop()!)
        }
        literal = l
    }
}

internal struct CommentLex: Lex {
    let prettyName = "Comment"
    let useLiteralDescription = true
    let literal: String
    let newLines: UInt

    init(_ chars: inout Fifo<String>) {
        var depth = 0
        var nl: UInt = 0
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
                nl += 1
            }
            rep.append(c)
        }

        literal = rep
        newLines = nl
    }
}

internal struct StringLex: Lex {
    let prettyName = "String"
    let useLiteralDescription = true
    let literal: String

    init(_ chars: inout Fifo<String>) {
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
        literal = rep
    }
}

internal struct IdentifierLex: Lex {
    let prettyName = "Identifier"
    let useLiteralDescription = true
    let literal: String

    init(_ chars: inout Fifo<String>, firstChar: Character) {
        var rep = String(firstChar)
        while chars.peek()?.isLetter ?? false {
            rep.append(chars.pop()!)
        }
        literal = rep
    }
}

internal struct NumberLex: Lex {
    let prettyName = "Number"
    let useLiteralDescription = true
    let value: Float
    var literal: String

    init(_ chars: inout Fifo<String>, firstChar: Character) {
        var rep = String(firstChar)

        var acceptDecimalPoint = firstChar != "."
        var acceptExponent = firstChar.isNumber
        var acceptSign = false

        while let c = chars.peek() {
            if c.isNumber {
                acceptExponent = true
                acceptSign = false
            } else if acceptDecimalPoint && c == "." {
                acceptDecimalPoint = false
                acceptExponent = false
            } else if acceptExponent && c.lowercased() == "e" {
                acceptDecimalPoint = false
                acceptSign = true
                acceptExponent = false
            } else if acceptSign && (c == "-" || c == "+") {
                acceptSign = false
            } else {
                break
            }
            rep.append(chars.pop()!)
        }

        literal = rep
        value = Float(rep)!
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

private func nextLexeme(_ chars: inout Fifo<String>) -> Lex? {
    guard let c = chars.pop() else { return nil }

    switch c {
    case "(":
        return CommentLex(&chars)
    case "\"":
        return StringLex(&chars)
    case "\r":
        return nextLexeme(&chars)
    case \.isNewline:
        return NewlineLex(c)
    case ",", "&":
        return DelimiterLex(c)
    case \.isWhitespace:
        return WhitespaceLex(&chars, firstChar: c)
    case \.isLetter:
        return IdentifierLex(&chars, firstChar: c)
    case \.isNumber, "+", "-", ".":
        return NumberLex(&chars, firstChar: c)
    default:
        assertionFailure("Found unlexable chars at end of input")
        return nil
    }
}

internal func lex(_ inp: String) -> [Lex] {
    var lexemes: [Lex] = []
    var chars = Fifo<String>(inp)

    while let l = nextLexeme(&chars) {
        lexemes.append(l)
    }

    return lexemes
}
