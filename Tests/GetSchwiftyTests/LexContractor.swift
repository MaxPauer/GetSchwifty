import XCTest
@testable import GetSchwifty

final class LexContractorTests: XCTestCase {
    func testRanges() throws {
        let testLex = {(inp: String, exp: [(Lex.Type, String, String?, (UInt,UInt), (UInt,UInt))]) in
            let lexemes = LexContractor(lexemes: LexIterator(input: inp))
            for (l,e) in zip(lexemes, exp) {
                let (t, lit, prettyLit, start, end) = e
                XCTAssert(type(of: l) == t)
                XCTAssertEqual(l.literal, lit)
                if prettyLit == nil {
                    XCTAssertNil(l.prettyLiteral)
                } else {
                    XCTAssertEqual(l.prettyLiteral!, prettyLit!)
                }
                var (line,char) = start
                XCTAssertEqual(l.range.start, LexPos(line: line, char: char))
                (line,char) = end
                XCTAssertEqual(l.range.end, LexPos(line: line, char: char))
            }
        }

        testLex("A's b'ee's an' c'ts", [
            (IdentifierLex.self, "A", "A",      (1,0), (1,1)),
            (IdentifierLex.self, "'s", "'s",    (1,1), (1,3)),
            (WhitespaceLex.self, " ", nil,      (1,3), (1,4)),
            (IdentifierLex.self, "bee", "b'ee", (1,4), (1,8)),
            (IdentifierLex.self, "'s", "'s",    (1,8), (1,10)),
            (WhitespaceLex.self, " ", nil,      (1,10), (1,11)),
            (IdentifierLex.self, "an", "an'",   (1,11), (1,14)),
            (WhitespaceLex.self, " ", nil,      (1,14), (1,15)),
            (IdentifierLex.self, "cts", "c'ts", (1,15), (1,19)),
            (NewlineLex.self,    "\u{03}", nil, (1,19), (2,0)),
        ])

        testLex("A's b'ee\n's \"an\"' c ' '' ts", [
            (IdentifierLex.self, "A", "A",      (1,0), (1,1)),
            (IdentifierLex.self, "'s", "'s",    (1,1), (1,3)),
            (WhitespaceLex.self, " ", nil,      (1,3), (1,4)),
            (IdentifierLex.self, "bee", "b'ee", (1,4), (1,8)),
            (NewlineLex.self,    "\n", nil,     (1,8), (2,0)),
            (IdentifierLex.self, "'s", "'s",    (2,0), (2,2)),
            (WhitespaceLex.self, " ", nil,      (2,2), (2,3)),
            (StringLex.self, "an", "\"an\"",    (2,3), (2,7)),
            (WhitespaceLex.self, "'", nil,      (2,7), (2,8)),
            (WhitespaceLex.self, " ", nil,      (2,8), (2,9)),
            (IdentifierLex.self, "c", "c",      (2,9), (2,10)),
            (WhitespaceLex.self, " ", nil,      (2,10), (2,11)),
            (WhitespaceLex.self, "'", nil,      (2,11), (2,12)),
            (WhitespaceLex.self, " ", nil,      (2,12), (2,13)),
            (WhitespaceLex.self, "'", nil,      (2,13), (2,14)),
            (WhitespaceLex.self, "'", nil,      (2,14), (2,15)),
            (WhitespaceLex.self, " ", nil,      (2,15), (2,16)),
            (IdentifierLex.self, "ts", "ts",    (2,16), (2,18)),
            (NewlineLex.self,    "\u{03}", nil, (2,18), (3,0)),
        ])
    }
}
