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
}
