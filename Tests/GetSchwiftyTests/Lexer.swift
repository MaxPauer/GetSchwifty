import XCTest
@testable import GetSchwifty

fileprivate struct WS {}
fileprivate struct NL {}
fileprivate struct SEP {}
fileprivate struct S {
    let s: String
}

final class LexerTests: XCTestCase {
    func testComments() throws {
        let testLex = { (inp: String, exp: String) in
            let lexemes = lex(inp) as! [CommentLex]
            XCTAssertEqual(lexemes.count, 1)
            XCTAssertEqual(lexemes[0].string_rep, exp)
        }

        testLex("(hi)", "hi")
        testLex("(hi", "hi")
        testLex("(he(llo))", "he(llo)")
        testLex("(he(ll)o)", "he(ll)o")
    }

    func testStrings() throws {
        let testLex = { (inp: String, exp: String) in
            let lexemes = lex(inp) as! [StringLex]
            XCTAssertEqual(lexemes.count, 1)
            XCTAssertEqual(lexemes[0].string_rep, exp)
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
            let lexemes = lex(inp) as! [WhitespaceLex]
            XCTAssertEqual(lexemes.count, exp)
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
                let l = (lexemes[i*2-2] as! WordLex).string_rep
                XCTAssert(exp.count == i || lexemes[i*2-1] is WhitespaceLex)
                XCTAssertEqual(e, l)
            }
        }

        testLex("hello", ["hello"])
        testLex("hello darkness", ["hello", "darkness"])
        testLex("hello darkness my old friend", ["hello", "darkness", "my", "old", "friend"])
    }

    func testNums() throws {
        let testLex = { (inp: String, exp: [Float]) in
            let lexemes = lex(inp) as! [NumberLex]
            XCTAssertEqual(lexemes.count, exp.count)
            for (e, l) in zip(exp, lexemes) {
                XCTAssertEqual(e, l.float_rep)
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
            case let l as WordLex: XCTAssertEqual(l.string_rep, e as! String)
            case let l as StringLex: XCTAssertEqual(l.string_rep, (e as! S).s)
            case _ as WhitespaceLex: XCTAssert(e is WS)
            case _ as NewlineLex: XCTAssert(e is NL)
            case _ as DelimiterLex: XCTAssert(e is SEP)
            default: XCTFail()
            }
        }
    }
}
