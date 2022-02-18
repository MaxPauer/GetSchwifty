import XCTest
@testable import GetSchwifty

fileprivate struct WS {}
fileprivate struct NL {}
fileprivate struct SEP {}
fileprivate struct S {
    let s: String
}

extension LexPos: Equatable {
    public static func ==(lhs: LexPos, rhs: LexPos) -> Bool {
        lhs.line == rhs.line && lhs.char == rhs.char
    }
}

final class LexerTests: XCTestCase {
    func testComments() throws {
        let testLex = { (inp: String, exp: String, expLines: UInt) in
            var lexemes = LexIterator(input: inp)
            let c = try XCTUnwrap(lexemes.next() as? CommentLex)
            XCTAssertEqual(c.range.end.line - c.range.start.line, expLines)

            _ = try XCTUnwrap(lexemes.next() as? NewlineLex)
            XCTAssertNil(lexemes.next())
            XCTAssertEqual(c.literal, exp)
        }

        try testLex("(hi)", "hi", 0)
        try testLex("(hi", "hi", 0)
        try testLex("(he(llo))", "he(llo)", 0)
        try testLex("(he(ll)o)", "he(ll)o", 0)
        try testLex("(he(\n)o)", "he(\n)o", 1)
        try testLex("(he(\n\r\n\r)o)", "he(\n\r\n\r)o", 2)
    }

    func testStrings() throws {
        let testLex = { (inp: String, exp: String) in
            var lexemes = LexIterator(input: inp)
            let str = try XCTUnwrap(lexemes.next() as? StringLex)
            XCTAssertEqual(str.literal, exp)

            _ = try XCTUnwrap(lexemes.next() as? NewlineLex)
            XCTAssertNil(lexemes.next())
        }

        try testLex("\"hi\"", "hi")
        try testLex("\"hi", "hi")
        try testLex("\"he\\\"ll\\\"o", "he\"ll\"o")
        try testLex("\"he\\\"ll\\o", "he\"ll\\o")
        try testLex("\"\\r\\n\\t\"", "\r\n\t")
        try testLex("\"hi\\", "hi\\")
        try testLex("\"hi\\", "hi\\")
        try testLex("\"hi\\\"", "hi\"")
        try testLex("\"hi\\a\"", "hi\\a")
    }

    func testNewlines() throws {
        let testLex = { (inp: String, exp: Int) in
            let lexemes = LexIterator(input: inp)
            var count = 0
            lexemes.forEach {
                count += 1
                XCTAssert($0 is NewlineLex)
            }
            XCTAssertEqual(count, exp)
        }

        testLex("", 0+1)
        testLex("\n", 1)
        testLex("\r", 0+1)
        testLex("\r\n", 1)
        testLex("\n\r\r\n", 2)
        testLex("\n\n\n\n", 4)
        testLex("\n\n\n\n\r", 4)
        testLex("\n\n\r\n\n\r", 4)
    }

    func testWhitespace() throws {
        let testLex = { (inp: String, exp: Int) in
            let lexemes = LexIterator(input: inp)
            let lexs = Array(lexemes)
            XCTAssertEqual(lexs.count-1, exp)
            lexs.dropLast().forEach {
                XCTAssert($0 is WhitespaceLex)
            }
        }

        testLex("", 0)
        testLex(" ", 1)
        testLex("  ", 1)
        testLex(" \t ", 1)
        testLex("  \t \t ", 1)
    }

    func testWhitespaceAndNewline() throws {
        let testLex = { (inp: String, exp: Int) in
            let lexemes = LexIterator(input: inp)
            var count = 0
            lexemes.forEach {
                count += 1
                XCTAssert($0 is WhitespaceLex || $0 is NewlineLex)
            }
            XCTAssertEqual(count, exp)
        }

        testLex("", 0+1)
        testLex(" ", 1+1)
        testLex("  ", 1+1)
        testLex("  \n", 2)
        testLex("\n ", 2+1)
        testLex("  \n ", 3+1)
        testLex("  \r\n\n ", 4+1)
        testLex("  \r\n\n \n", 5)
    }

    func testWords() throws {
        let testLex = { (inp: String, exp: [String]) in
            var lexemes = LexIterator(input: inp)
            for e in exp {
                let id = try XCTUnwrap(lexemes.next() as? IdentifierLex)
                XCTAssert(e == exp.last || lexemes.next() is WhitespaceLex)
                XCTAssertEqual(e, id.literal)
            }
            XCTAssert(lexemes.next() is NewlineLex)
            XCTAssertNil(lexemes.next())
        }

        try testLex("hello", ["hello"])
        try testLex("hello darkness", ["hello", "darkness"])
        try testLex("hello darkness my old friend", ["hello", "darkness", "my", "old", "friend"])
    }

    func testNums() throws {
        let testLex = { (inp: String, exp: [Double]) in
            var lexemes = LexIterator(input: inp)
            for e in exp {
                let l = lexemes.next()
                let num = try! XCTUnwrap(l as? NumberLex)
                XCTAssertEqual(e, Double(num.literal)!)
            }
            XCTAssert(lexemes.next() is NewlineLex)
            XCTAssertNil(lexemes.next())
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
            var lexemes = LexIterator(input: inp)
            for _ in 1...exp {
                XCTAssert(lexemes.next() is DelimiterLex)
            }
            XCTAssert(lexemes.next() is NewlineLex)
            XCTAssertNil(lexemes.next())
        }

        testLex(",", 1)
        testLex(",,", 2)
        testLex("&,,", 3)
        testLex("&", 1)
        testLex(",&&,", 4)
    }

    func testRanges() throws {
        let testLex = {(inp: String, exp: [(Lex.Type, (UInt,UInt), (UInt,UInt))]) in
            let lexemes = LexIterator(input: inp)
            for (l,e) in zip(lexemes, exp) {
                let (t, start, end) = e
                XCTAssert(type(of: l) == t)
                var (line,char) = start
                XCTAssertEqual(l.range.start, LexPos(line: line, char: char))
                (line,char) = end
                XCTAssertEqual(l.range.end, LexPos(line: line, char: char))
            }
        }

        testLex("A  dream is 2.5 (that's\nsick)", [
            (IdentifierLex.self, (1,0), (1,1)),
            (WhitespaceLex.self, (1,1), (1,3)),
            (IdentifierLex.self, (1,3), (1,8)),
            (WhitespaceLex.self, (1,8), (1,9)),
            (IdentifierLex.self, (1,9), (1,11)),
            (WhitespaceLex.self, (1,11), (1,12)),
            (NumberLex.self,     (1,12), (1,15)),
            (WhitespaceLex.self, (1,15), (1,16)),
            (CommentLex.self,    (1,16), (2,5)),
            (NewlineLex.self,    (2,5), (3,0)),
        ])

        testLex("\n\"A\t\r\ndream\" isn't \"nice\"&cool", [
            (NewlineLex.self,    (1,0), (2,0)),
            (StringLex.self,    (2,0), (3,6)),
            (WhitespaceLex.self, (3,6), (3,7)),
            (IdentifierLex.self, (3,7), (3,10)),
            (ApostropheLex.self, (3,10), (3,11)),
            (IdentifierLex.self, (3,11), (3,12)),
            (WhitespaceLex.self, (3,12), (3,13)),
            (StringLex.self,     (3,13), (3,19)),
            (DelimiterLex.self,  (3,19), (3,20)),
            (IdentifierLex.self, (3,20), (3,24)),
            (NewlineLex.self,    (3,24), (4,0)),
        ])
    }

    func testFizzBuzz() throws {
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))
        let lexemes = LexIterator(input: fizzbuzz)

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

        var count = 0
        for (lex, e) in zip (lexemes, expected) {
            count += 1
            switch lex {
            case let id as IdentifierLex: XCTAssertEqual(id.literal, e as! String)
            case let str as StringLex:    XCTAssertEqual(str.literal, (e as! S).s)
            case is WhitespaceLex:        XCTAssert(e is WS)
            case is NewlineLex:           XCTAssert(e is NL)
            case is DelimiterLex:         XCTAssert(e is SEP)
            default:                      XCTFail()
            }
        }
        XCTAssertEqual(count, expected.count)
    }
}
