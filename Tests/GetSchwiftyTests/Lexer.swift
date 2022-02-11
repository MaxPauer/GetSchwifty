import XCTest
@testable import GetSchwifty

final class LexerTests: XCTestCase {
    func testComments() throws {
        let testLex = { (inp: String, exp: String) in
            let lexemes = lex(inp) as! [StringLexeme]
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
            let lexemes = lex(inp) as! [StringLexeme]
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
            let lexemes = lex(inp)
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
                let l = (lexemes[i*2-2] as! StringLexeme).string_rep
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
}
