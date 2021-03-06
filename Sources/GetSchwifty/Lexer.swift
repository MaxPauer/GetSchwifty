prefix operator ↵
prefix operator →

private typealias StringFifo = Fifo<String.Iterator>

struct LexPos {
    let line: UInt
    let char: UInt

    // swiftlint:disable:next identifier_name
    static prefix func → (op: LexPos) -> LexPos {
        LexPos(line: op.line, char: op.char+1)
    }
    // swiftlint:disable:next identifier_name
    static prefix func ↵ (op: LexPos) -> LexPos {
        LexPos(line: op.line+1, char: 0)
    }
    static func - (end: LexPos, start: LexPos) -> LexRange {
        LexRange(start: start, end: end)
    }
    static prefix func - (end: LexPos) -> LexRange {
        return end-end
    }
    static var origin: LexPos { LexPos(line: 1, char: 0) }
}

struct LexRange {
    let start: LexPos
    let end: LexPos

    static func + (lhs: LexRange, rhs: LexRange) -> LexRange {
        LexRange(start: lhs.start, end: rhs.end)
    }
}

protocol Lex: PrettyNamed {
    var prettyLiteral: String? { get }
    var literal: String { get }
    var range: LexRange { get }
}

struct NewlineLex: Lex {
    let literal: String
    let range: LexRange
    static let EOF: Character = "\u{03}"

    var prettyLiteral: String? {
        String(literal.map {
            switch $0 {
            case "\r": return "␍"
            case "\n": return "␊"
            case Self.EOF: return "␃"
            default: return $0
            }
        })
    }

    fileprivate init(_ c: Character, start: LexPos) {
        literal = String(c)
        range = (↵start)-start
    }

    init(EOF start: LexPos) {
        self.init(Self.EOF, start: start)
    }
}

struct DelimiterLex: Lex {
    let prettyLiteral: String? = nil
    let literal: String
    let range: LexRange

    init(_ c: Character, start: LexPos) {
        literal = String(c)
        range = (→start)-start
    }
}

struct ContractionLex: Lex {
    var prettyLiteral: String? { "'\(literal)" }
    let literal: String
    let range: LexRange

    fileprivate init(_ chars: inout StringFifo, start: LexPos) {
        var rep = ""
        var end = →start
        while chars.peek()?.isLetter ?? false {
            end = →end
            rep.append(chars.pop()!)
        }
        literal = rep
        range = end-start
    }
}

struct WhitespaceLex: Lex {
    let literal: String
    let range: LexRange

    var prettyLiteral: String? {
        String(literal.map {
            switch $0 {
            case " ": return "␣"
            case "\t": return "→"
            case \.isWhitespace: return "⋅"
            default: return $0
            }
        })
    }

    fileprivate init(_ chars: inout StringFifo, firstChar: Character, start: LexPos) {
        var l = String(firstChar)
        var end = →start
        while let c = chars.peek() {
            guard c.isWhitespace && !c.isNewline else { break }
            end = →end
            l.append(chars.pop()!)
        }
        literal = l
        range = end-start
    }

    init(literal l: String, range r: LexRange) {
        literal = l
        range = r
    }
}

struct CommentLex: Lex {
    var prettyLiteral: String? { "(\(literal))" }
    let literal: String
    let range: LexRange

    fileprivate init(_ chars: inout StringFifo, start: LexPos) {
        var depth = 0
        var end = →start
        var rep = ""

        while let c = chars.pop() {
            if c == ")" {
                if depth == 0 {
                    end = →end
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

struct StringLex: Lex {
    var prettyLiteral: String? { "\"\(literal)\"" }
    let literal: String
    let range: LexRange

    // swiftlint:disable:next cyclomatic_complexity
    fileprivate init(_ chars: inout StringFifo, start: LexPos) {
        var rep = ""
        var end = →start
        while let c = chars.pop() {
            if c == "\"" {
                end = →end
                break
            }

            if c == "\\" {
                if let escapee = chars.pop() {
                    end = →(→end)
                    switch escapee {
                    case "n": rep.append("\n")
                    case "r": rep.append("\r")
                    case "t": rep.append("\t")
                    case "\\": rep.append("\\")
                    case "\"": rep.append("\"")
                    default:
                        rep.append(c)
                        rep.append(escapee)
                    }
                    continue
                }
            }

            rep.append(c)
            if c.isNewline {
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

struct IdentifierLex: Lex {
    let prettyLiteral: String?
    let literal: String
    let range: LexRange

    fileprivate init(_ chars: inout StringFifo, firstChar: Character, start: LexPos) {
        var rep = String(firstChar)
        var end = →start
        while chars.peek()?.isLetter ?? false {
            end = →end
            rep.append(chars.pop()!)
        }
        self.init(literal: rep, range: end-start)
    }

    init(literal l: String, range r: LexRange) {
        self.init(literal: l, prettyLiteral: l, range: r)
    }

    init(literal l: String, prettyLiteral p: String, range r: LexRange) {
        literal = l
        prettyLiteral = p
        range = r
    }
}

struct NumberLex: Lex {
    var prettyLiteral: String? { literal }
    var literal: String
    let range: LexRange

    fileprivate static func possibly(_ chars: inout StringFifo, firstChar: Character, start: LexPos) -> Lex {
        var rep = String(firstChar)
        var end = →start

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

        let range = end-start
        if !firstChar.isNumber && rep.count == 1 {
            return WhitespaceLex(literal: rep, range: range)
        }
        return NumberLex(literal: rep, range: range)
    }
}

fileprivate extension Character {
    var isNewline: Bool {
        self == "\n" || self == "\r\n"
    }
}

func ~= <T>(pattern: KeyPath<T, Bool>, value: T) -> Bool {
    value[keyPath: pattern]
}

// swiftlint:disable:next cyclomatic_complexity
private func nextLexeme(_ chars: inout StringFifo, start: LexPos) -> Lex? {
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
        return ContractionLex(&chars, start: start)
    case \.isWhitespace:
        return WhitespaceLex(&chars, firstChar: c, start: start)
    case \.isLetter:
        return IdentifierLex(&chars, firstChar: c, start: start)
    case \.isNumber, "+", "-", ".":
        return NumberLex.possibly(&chars, firstChar: c, start: start)
    default:
        return WhitespaceLex(&chars, firstChar: c, start: start)
    }
}

struct LexIterator: Sequence, IteratorProtocol {
    private var chars: StringFifo
    var start: LexPos
    var lineTerminated = false

    init(input inp: String) {
        chars = StringFifo(inp.makeIterator())
        start = LexPos.origin
    }

    mutating func next() -> Lex? {
        if let current = nextLexeme(&chars, start: start) {
            start = current.range.end
            lineTerminated = current is NewlineLex
            return current
        } else if !lineTerminated {
            lineTerminated = true
            return NewlineLex(EOF: start)
        }
        return nil
    }
}
