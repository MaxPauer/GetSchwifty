prefix operator ↵
prefix operator →

internal struct LexPos {
    let line: UInt
    let char: UInt

    static prefix func →(op: LexPos) -> LexPos {
        LexPos(line: op.line, char: op.char+1)
    }
    static prefix func ↵(op: LexPos) -> LexPos {
        LexPos(line: op.line+1, char: 1)
    }
    static func -(end: LexPos, start: LexPos) -> LexRange {
        LexRange(start: start, end: end)
    }
}

internal struct LexRange {
    let start: LexPos
    let end: LexPos
}

internal protocol Lex: CustomStringConvertible {
    var prettyName: String { get }
    var useLiteralDescription: Bool { get }
    var literal: String { get }
    var range: LexRange { get }
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
    let range: LexRange

    init(_ c: Character, start: LexPos) {
        literal = String(c)
        range = (↵start)-start
    }
}

internal struct DelimiterLex: Lex {
    let prettyName = "Delimiter"
    let useLiteralDescription = false
    let literal: String
    let range: LexRange

    init(_ c: Character, start: LexPos) {
        literal = String(c)
        range = (→start)-start
    }
}

internal struct ApostropheLex: Lex {
    let prettyName = "Apostrophe"
    let useLiteralDescription = false
    let literal = "'"
    let range: LexRange

    init(start: LexPos) {
        range = (→start)-start
    }
}

internal struct WhitespaceLex: Lex {
    let prettyName = "Whitespace"
    let useLiteralDescription = false
    let literal: String
    let range: LexRange

    init(_ chars: inout Fifo<String>, firstChar: Character, start: LexPos) {
        var l = String(firstChar)
        var end = start
        while let c = chars.peek() {
            guard c.isWhitespace && !c.isNewline else { break }
            end = →end
            l.append(chars.pop()!)
        }
        literal = l
        range = end-start
    }
}

internal struct CommentLex: Lex {
    let prettyName = "Comment"
    let useLiteralDescription = true
    let literal: String
    let range: LexRange

    init(_ chars: inout Fifo<String>, start: LexPos) {
        var depth = 0
        var end = start
        var rep = ""

        while let c = chars.pop() {
            if c == ")" {
                if depth == 0 {
                    break
                }
                depth -= 1
            }

            rep.append(c)
            if c.isNewline {
                end = ↵end
                continue
            }

            end = →end
            if c == "(" {
                depth += 1
            }
        }

        range = end-start
        literal = rep
    }
}

internal struct StringLex: Lex {
    let prettyName = "String"
    let useLiteralDescription = true
    let literal: String
    let range: LexRange

    init(_ chars: inout Fifo<String>, start: LexPos) {
        var rep = ""
        var end = start
        while let c = chars.pop() {
            if c == "\"" {
                end = →end
                break
            }

            rep.append(c)
            if c == "\\" {
                rep.append(chars.pop()!)
                end = →(→end)
                continue
            } else if c.isNewline {
                end = ↵end
                continue
            } else {
                end = →end
            }
        }

        range = end-start
        literal = rep
    }
}

internal struct IdentifierLex: Lex {
    let prettyName = "Identifier"
    let useLiteralDescription = true
    let literal: String
    let range: LexRange

    init(_ chars: inout Fifo<String>, firstChar: Character, start: LexPos) {
        var rep = String(firstChar)
        var end = start
        while chars.peek()?.isLetter ?? false {
            end = →end
            rep.append(chars.pop()!)
        }
        literal = rep
        range = end-start
    }
}

internal struct NumberLex: Lex {
    let prettyName = "Number"
    let useLiteralDescription = true
    let value: Float
    var literal: String
    let range: LexRange

    init(_ chars: inout Fifo<String>, firstChar: Character, start: LexPos) {
        var rep = String(firstChar)
        var end = start

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
            end = →end
            rep.append(chars.pop()!)
        }

        range = end-start
        literal = rep
        value = Float(rep)!
    }
}

fileprivate extension Character {
    var isNewline: Bool {
        self == "\n" || self == "\r\n"
    }
}

internal func ~=<T>(pattern: KeyPath<T, Bool>, value: T) -> Bool {
    value[keyPath: pattern]
}

private func nextLexeme(_ chars: inout Fifo<String>, start: LexPos) -> Lex? {
    guard let c = chars.pop() else { return nil }

    switch c {
    case "(":
        return CommentLex(&chars, start: start)
    case "\"":
        return StringLex(&chars, start: start)
    case "\r":
        return nextLexeme(&chars, start: start)
    case \.isNewline:
        return NewlineLex(c, start: start)
    case ",", "&":
        return DelimiterLex(c, start: start)
    case "'":
        return ApostropheLex(start: start)
    case \.isWhitespace:
        return WhitespaceLex(&chars, firstChar: c, start: start)
    case \.isLetter:
        return IdentifierLex(&chars, firstChar: c, start: start)
    case \.isNumber, "+", "-", ".":
        return NumberLex(&chars, firstChar: c, start: start)
    default:
        assertionFailure("Found unlexable chars at end of input")
        return nil
    }
}

internal func lex(_ inp: String) -> [Lex] {
    var chars = Fifo<String>(inp)
    var lexemes: [Lex] = []
    var start = LexPos(line: 1, char: 1)

    while let l = nextLexeme(&chars, start: start) {
        lexemes.append(l)
        start = →l.range.end
    }

    if !(lexemes.last is NewlineLex) {
        lexemes.append(NewlineLex("\u{03}", start: start))
    }

    return lexemes
}
