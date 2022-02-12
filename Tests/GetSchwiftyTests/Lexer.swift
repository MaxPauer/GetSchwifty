import XCTest
@testable import GetSchwifty

fileprivate extension Lexeme {
    var word: String? {
        guard case .word(let w) = self else { return nil }
        return w
    }
    var string: String? {
        guard case .string(let s) = self else { return nil }
        return s
    }
    var comment: (String, UInt)? {
        guard case .comment(let s, let l) = self else { return nil }
        return (s,l)
    }
    var number: Float? {
        guard case .number(let f) = self else { return nil }
        return f
    }
}

fileprivate struct WS {}
fileprivate struct NL {}
fileprivate struct SEP {}
fileprivate struct S {
    let s: String
}

final class LexerTests: XCTestCase {
    func testComments() throws {
        let testLex = { (inp: String, exp: String, exp_lines: UInt) in
            let lexemes = lex(inp)
            XCTAssertEqual(lexemes.count, 1)
            let (string_rep, lines) = try! XCTUnwrap(lexemes[0].comment)
            XCTAssertEqual(string_rep, exp)
            XCTAssertEqual(lines, exp_lines)
        }

        testLex("(hi)", "hi", 1)
        testLex("(hi", "hi", 1)
        testLex("(he(llo))", "he(llo)", 1)
        testLex("(he(ll)o)", "he(ll)o", 1)
        testLex("(he(\n)o)", "he(\n)o", 2)
        testLex("(he(\n\r\n\r)o)", "he(\n\r\n\r)o", 3)
    }

    func testStrings() throws {
        let testLex = { (inp: String, exp: String) in
            let lexemes = lex(inp)
            XCTAssertEqual(lexemes.count, 1)
            let string_rep = try! XCTUnwrap(lexemes[0].string)
            XCTAssertEqual(string_rep, exp)
        }

        testLex("\"hi\"", "hi")
        testLex("\"hi", "hi")
        testLex("\"he\\\"ll\\\"o", "he\\\"ll\\\"o")
        testLex("\"he\\\"ll\\o", "he\\\"ll\\o")
    }

    func testNewlines() throws {
        let testLex = { (inp: String, exp: Int) in
            let lexemes = lex(inp)
            XCTAssertEqual(lexemes.count, exp)
            lexemes.forEach {
                XCTAssertEqual($0, .newline)
            }
        }

        testLex("\n", 1)
        testLex("\r", 0)
        testLex("\r\n", 1)
        testLex("\n\r\r\n", 2)
        testLex("\n\n\n\n", 4)
        testLex("\n\n\n\n\r", 4)
        testLex("\n\n\r\n\n\r", 4)
    }

    func testWhitespace() throws {
        let testLex = { (inp: String, exp: Int) in
            let lexemes = lex(inp)
            XCTAssertEqual(lexemes.count, exp)
            lexemes.forEach {
                XCTAssertEqual($0, .whitespace)
            }
        }

        testLex("", 0)
        testLex(" ", 1)
        testLex("  ", 1)
        testLex(" \t ", 1)
        testLex("  \t \t ", 1)
    }

    func testWords() throws {
        let testLex = { (inp: String, exp: [String]) in
            let lexemes = lex(inp)
            XCTAssertEqual(lexemes.count, exp.count*2-1)
            for i in 1...exp.count {
                let e = exp[i-1]
                let w = try! XCTUnwrap(lexemes[i*2-2].word)
                XCTAssert(exp.count == i || lexemes[i*2-1] == .whitespace)
                XCTAssertEqual(e, w)
            }
        }

        testLex("hello", ["hello"])
        testLex("hello darkness", ["hello", "darkness"])
        testLex("hello darkness my old friend", ["hello", "darkness", "my", "old", "friend"])
    }

    func testNums() throws {
        let testLex = { (inp: String, exp: [Float]) in
            let lexemes = lex(inp)
            XCTAssertEqual(lexemes.count, exp.count)
            for (e, l) in zip(exp, lexemes) {
                let f = try! XCTUnwrap(l.number)
                XCTAssertEqual(e, f)
            }
        }

        testLex("0", [0])
        testLex("1", [1.0])
        testLex("123", [123])
        testLex("+23", [23])
        testLex("-23", [-23])
        testLex("1.23", [1.23])
        testLex("1.2e3", [1.2e3])
        testLex("1.2E3", [1.2e3])
        testLex("12e3", [12e3])
        testLex("-1.2e+3", [-1.2e+3])
        testLex("-1.2E-3", [-1.2e-3])
        testLex("1.2e3", [1.2e3])
        testLex(".23", [0.23])
        testLex(".11.99", [0.11, 0.99])
        testLex("22+33", [22, 33])
        testLex("-4e-3", [-4e-3])
    }

    func testDelimiter() throws {
        let testLex = { (inp: String, exp: Int) in
            let lexemes = lex(inp)
            XCTAssertEqual(lexemes.count, exp)
            lexemes.forEach {
                XCTAssertEqual($0, .delimiter)
            }
        }

        testLex(",", 1)
        testLex(",,", 2)
        testLex("&,,", 3)
        testLex("&", 1)
        testLex(",&&,", 4)
    }

    func testFizzBuzz() throws {
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))
        let lexemes = lex(fizzbuzz)

        let expected: [Any] = [
            "Midnight", WS(), "takes", WS(), "your", WS(), "heart", WS(), "and", WS(), "your", WS(), "soul", NL(),
            "While", WS(), "your", WS(), "heart", WS(), "is", WS(), "as", WS(), "high", WS(), "as", WS(), "your", WS(), "soul", NL(),
            "Put", WS(), "your", WS(), "heart", WS(), "without", WS(), "your", WS(), "soul", WS(), "into", WS(), "your", WS(), "heart", NL(),
            NL(),
            "Give", WS(), "back", WS(), "your", WS(), "heart", NL(),
            NL(),
            "Desire", WS(), "is", WS(), "a", WS(), "lovestruck", WS(), "ladykiller", NL(),
            "My", WS(), "world", WS(), "is", WS(), "nothing", NL(),
            "Fire", WS(), "is", WS(), "ice", NL(),
            "Hate", WS(), "is", WS(), "water", NL(),
            "Until", WS(), "my", WS(), "world", WS(), "is", WS(), "Desire", SEP(), NL(),
            "Build", WS(), "my", WS(), "world", WS(), "up", NL(),
            "If", WS(), "Midnight", WS(), "taking", WS(), "my", WS(), "world", SEP(), WS(), "Fire", WS(), "is", WS(), "nothing", WS(), "and", WS(), "Midnight", WS(), "taking", WS(), "my", WS(), "world", SEP(), WS(), "Hate", WS(), "is", WS(), "nothing", NL(),
            "Shout", WS(), S(s: "FizzBuzz!"), NL(),
            "Take", WS(), "it", WS(), "to", WS(), "the", WS(), "top", NL(),
            NL(),
            "If", WS(), "Midnight", WS(), "taking", WS(), "my", WS(), "world", SEP(), WS(), "Fire", WS(), "is", WS(), "nothing", NL(),
            "Shout", WS(), S(s: "Fizz!"), NL(),
            "Take", WS(), "it", WS(), "to", WS(), "the", WS(), "top", NL(),
            NL(),
            "If", WS(), "Midnight", WS(), "taking", WS(), "my", WS(), "world", SEP(), WS(), "Hate", WS(), "is", WS(), "nothing", NL(),
            "Say", WS(), S(s: "Buzz!"), NL(),
            "Take", WS(), "it", WS(), "to", WS(), "the", WS(), "top", NL(),
            NL(),
            "Whisper", WS(), "my", WS(), "world", NL()
        ]

        XCTAssertEqual(lexemes.count, expected.count)
        for (lex, e) in zip(lexemes, expected) {
            switch lex {
            case .word(let w):   XCTAssertEqual(w, e as! String)
            case .string(let s): XCTAssertEqual(s, (e as! S).s)
            case .whitespace:    XCTAssert(e is WS)
            case .newline:       XCTAssert(e is NL)
            case .delimiter:     XCTAssert(e is SEP)
            default:             XCTFail()
            }
        }
    }
}
