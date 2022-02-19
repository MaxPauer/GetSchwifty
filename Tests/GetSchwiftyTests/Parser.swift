import XCTest
@testable import GetSchwifty

final class ParserTests: XCTestCase {
    func parse(_ inp: String) throws -> Parser {
        return Parser(input: inp)
    }

    func testVariableNames() throws {
        func testParse(_ inp: String, _ exp: String) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let v = try XCTUnwrap(try p.next() as? VariableNameExpr)
            XCTAssertEqual(v.name, exp)
            XCTAssertNil(try p.next())
        }

        try testParse("A horse", "a horse")
        try testParse("An  elf", "an elf")
        try testParse("THE HOUSE", "the house")
        try testParse("My\tlife", "my life")
        try testParse("your Heart", "your heart")
        try testParse("our SoCiEtY", "our society")
        try testParse("Doctor Feelgood", "doctor feelgood")
        try testParse("Distance In Km", "distance in km")
        try testParse("Doctor", "doctor")
        try testParse("she'lob", "shelob")
    }

    func testPronouns() throws {
        for inp in ["it", "he", "she", "him", "her", "they", "them", "th'em", "ze", "hir", "zie", "zir", "xe", "xem", "ve", "ver"] {
            var p = try XCTUnwrap(self.parse(inp))
            _ = try XCTUnwrap(try p.next() as? PronounExpr)
            XCTAssertNil(try p.next())
        }
    }

    func assignParseTest<U, V>(_ inp: String, _ expVarName: String, _ expValue: U) throws -> V where U: Equatable, V: LeafExpr, V.LiteralType == U {
        var p = try XCTUnwrap(self.parse(inp))
        let ass = try p.next() as! AssignmentExpr
        XCTAssertNil(try p.next())
        XCTAssertEqual((ass.target as! VariableNameExpr).name, expVarName)
        let rhs = try XCTUnwrap(ass.value as? V)
        XCTAssertEqual(rhs.literal, expValue)
        return rhs
    }

    func testPoeticNumberLiteral() throws {
        let _: NumberExpr = try assignParseTest("heaven is a halfpipe", "heaven", 18)
        let _: NumberExpr = try assignParseTest("My life's fucked", "my life", 6)
        let _: NumberExpr = try assignParseTest("My life's gone", "my life", 4)
        let _: NumberExpr = try assignParseTest("Your lies're my death", "your lies", 25)
        let _: NumberExpr = try assignParseTest("Your lies're my death's death", "your lies", 265)
        let _: NumberExpr = try assignParseTest("My life's fucked''", "my life", 6)
        let _: NumberExpr = try assignParseTest("My life's fucked'd", "my life", 7)
        let _: NumberExpr = try assignParseTest("My life's  fucked'd", "my life", 7)
        let _: NumberExpr = try assignParseTest("My life's fucked'd ", "my life", 7)
        let _: NumberExpr = try assignParseTest("My life's fucked''d", "my life", 7)
        let _: NumberExpr = try assignParseTest("My life's fucked'd'd", "my life", 8)
        let _: NumberExpr = try assignParseTest("heaven is a halfhalfpipe", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a halfhalfpipe''", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a ha'lfhalfpipe", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a ha''lfhalfpipe", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a half'halfpipe", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a halfhalfpi'pe", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a half'halfpi'pe", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a h'a'l'f'h'a'l'f'p'i'p'e", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a h'a'l'f'h'a'l'f'p'i'p'e'", "heaven", 12)
    }

    func testPoeticStringLiteral() throws {
        let _: StringExpr = try assignParseTest("(when i was 17) my father said to me A wealthy man had the things I wanted", "my father", "to me A wealthy man had the things I wanted")
        let _: StringExpr = try assignParseTest("(when i was 17) my father said to me A wealthy man had the thing's I wanted", "my father", "to me A wealthy man had the thing's I wanted")
        let _: StringExpr = try assignParseTest("(when i was 17) my father said to me A wealthy man had the things I wan'ed", "my father", "to me A wealthy man had the things I wan'ed")
        let _: StringExpr = try assignParseTest("(when i was 17) my father said to me A wealthy man had the things I waned'", "my father", "to me A wealthy man had the things I waned'")
        let _: StringExpr = try assignParseTest("Mother says good \"night\" good(fright)\t good124.5e2", "mother", "good \"night\" good(fright)\t good124.5e2")
        let _: StringExpr = try assignParseTest("Father say \\ lala 'sick hui'  ", "father", "\\ lala 'sick hui'  ")
        let _: StringExpr = try assignParseTest("brother say ", "brother", "")
        let _: StringExpr = try assignParseTest("my father said", "my father", "")
    }

    func testLetAssignment() throws {
        let _: StringExpr = try assignParseTest("let my life be \"GREAT\"", "my life", "GREAT")
        let _: NumberExpr = try assignParseTest("let my life be 42.0", "my life", 42.0)
        let _: BoolExpr = try assignParseTest("let The Devil be right", "the devil", true)
        let _: BoolExpr = try assignParseTest("let The Devil be wrong", "the devil", false)
        let _: NullExpr = try assignParseTest("let hate be nothing", "hate", nil)
        let _: MysteriousExpr = try assignParseTest("let dragons be mysterious", "dragons", nil)
    }

    func testPutAssignment() throws {
        let _: NumberExpr = try assignParseTest("put 42 in my life", "my life", 42.0)
        let _: StringExpr = try assignParseTest("put \"squirrels\" into my pants", "my pants", "squirrels")
        let _: StringExpr = try assignParseTest("put silence into my pants", "my pants", "")
    }

    func testInput() throws {
        let testParse = { (inp: String, expLocName: String?) in
            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(try p.next() as? InputExpr)
            XCTAssertNil(try p.next())
            if let elc = expLocName {
                XCTAssertEqual(try XCTUnwrap(i.target as? VariableNameExpr).name, elc)
            } else {
                XCTAssertNil(i.target)
            }
        }

        try testParse("Listen", nil)
        try testParse("Listen ", nil)
        try testParse("L'isten ", nil)
        try testParse("Listen to my heart", "my heart")
    }

    func testOutput() throws {
        func testParse<T>(_ inp: String) throws -> T {
            var p = try XCTUnwrap(self.parse(inp))
            let o = try XCTUnwrap(p.next() as? OutputExpr)
            let t = try XCTUnwrap(o.target as? T)
            XCTAssertNil(try p.next())
            return t
        }

        let _: VariableNameExpr = try testParse("Shout my name")
        let _: VariableNameExpr = try testParse("whisper my name")
        let _: VariableNameExpr = try testParse("scream my name")
        let _: VariableNameExpr = try testParse("say my name") // Heisenberg
        let _: BoolExpr = try testParse("whisper yes")
        let _: PronounExpr = try testParse("shout it")
    }

    func testIncDecrement() throws {
        func testParse<T>(_ inp: String, _ value: Int) throws -> T {
            var p = try XCTUnwrap(self.parse(inp))
            let o = try XCTUnwrap(p.next() as? CrementExpr)
            let t = try XCTUnwrap(o.target as? T)
            XCTAssertEqual(o.value, value)
            return t
        }

        let _: VariableNameExpr = try testParse("build me", 0)
        let _: VariableNameExpr = try testParse("build me up", 1)
        let _: VariableNameExpr = try testParse("build me up up", 2)
        let _: VariableNameExpr = try testParse("build me up up, up & up", 4)

        let _: PronounExpr = try testParse("knock him", 0)
        let _: PronounExpr = try testParse("knock him down", -1)
        let _: PronounExpr = try testParse("knock him down, down", -2)
        let _: IndexingLocationExpr = try testParse("knock him at 0 down,down down", -3)
    }

    func testFizzBuzz() throws {
        func parseDiscardAll(_ inp: String) throws {
            var p = Parser(input: inp)
            while let _ = try p.next() {}
        }
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))
        XCTAssertThrowsError(try parseDiscardAll(fizzbuzz)) { error in
            let e = try! XCTUnwrap(error as? UnexpectedIdentifierError)
            XCTAssertEqual(e.got.range.start, LexPos(line: 1, char: 9))
        }
        // XCTAssertEqual(parser.lines, 26)
    }
}
