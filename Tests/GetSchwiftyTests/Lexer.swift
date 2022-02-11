import XCTest
@testable import GetSchwifty

final class LexerTests: XCTestCase {
    func testLexer() throws {
        let testLex = { (inp: String, exp: String) in
            let lexemes = lex(inp)
            XCTAssertEqual(lexemes.count, 1)
            XCTAssertEqual(lexemes[0].string_rep, exp)
        }

        testLex("(hi)", "hi")
        testLex("(hi", "hi")
        testLex("(he(llo))", "he(llo)")
        testLex("(he(ll)o)", "he(ll)o")
    }
}
