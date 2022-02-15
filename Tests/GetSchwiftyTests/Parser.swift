import XCTest
@testable import GetSchwifty

final class ParserTests: XCTestCase {
    func parse(_ inp: String) throws -> [Expr] {
        let p = try Parser(lexemes: lex(inp))
        return p.rootExpr.children
    }

    func testCommonVariable() throws {
        let testParse = { (inp: String, exp: [String]) in
            let exprs = try! self.parse(inp)
            XCTAssertEqual(exprs.count, exp.count)
            for (v, e) in zip(exprs, exp) {
                XCTAssertEqual((v as! CommonVariableNameExpr).name, e)
            }
        }

        testParse("A horse", ["a horse"])
        testParse("An  elf", ["an elf"])
        testParse("THE HOUSE", ["the house"])
        testParse("My\tlife", ["my life"])
        testParse("your Heart", ["your heart"])
        testParse("our SoCiEtY", ["our society"])
    }

    func testCommonVariableFailure() {
        let testParse = { (inp: String, err: ParserError.Type, got: Lex.Type?, parsing: Expr.Type) in
            XCTAssertThrowsError(try self.parse(inp)) { (e: Error) in
                let error = e as! ParserError
                XCTAssert(type(of: error) == err)
                switch error {
                case let err as UnexpectedLexemeError:
                    XCTAssert(type(of: err.parsing) == parsing)
                    XCTAssert(type(of: err.got) == got!)
                case let err as UnexpectedEOLError:
                    XCTAssert(type(of: err.parsing) == parsing)
                default:
                    XCTFail("Unexpected Error type")
                }
            }
        }

        try! testParse("A\"field\"", UnexpectedLexemeError.self, StringLex.self, CommonVariableNameExpr.self)
        try! testParse("A,field", UnexpectedLexemeError.self, DelimiterLex.self, CommonVariableNameExpr.self)
        try! testParse("A\nfield", UnexpectedEOLError.self, nil, CommonVariableNameExpr.self)
        try! testParse("A ", UnexpectedEOLError.self, nil, CommonVariableNameExpr.self)
        try! testParse("A \n", UnexpectedEOLError.self, nil, CommonVariableNameExpr.self)
    }

    func assignParseTest<U, V, W>(_ inp: String, _ expVarName: String, _ expValue: U) -> (V,W) where U: Equatable, V: LeafExpr, V.LiteralType == U, W: AnyAssignmentExpr {
        let exprs = try! self.parse(inp)
        XCTAssertEqual(exprs.count, 1)
        let ass = exprs[0] as! W
        XCTAssertEqual((ass.target as! CommonVariableNameExpr).name, expVarName)
        let rhs = try! XCTUnwrap(ass.value as? V)
        XCTAssertEqual(rhs.literal, expValue)
        return (rhs, ass)
    }

    func testPoeticNumberLiteral() throws {
        let _: (NumberExpr, PoeticNumberAssignmentExpr) = assignParseTest("My heaven is a halfpipe", "my heaven", 18)
    }

    func testPoeticStringLiteral() throws {
        let _: (StringExpr, PoeticStringAssignmentExpr) = assignParseTest("my father said to me A wealthy man had the things I wanted", "my father", "to me A wealthy man had the things I wanted")
    }

    func testLetAssignment() throws {
        let _: (StringExpr, AssignmentExpr) = assignParseTest("let my life be \"GREAT\"", "my life", "GREAT")
        let _: (NumberExpr, AssignmentExpr) = assignParseTest("let my life be 42.0", "my life", 42.0)
    }

    func testPutAssignment() throws {
        let _: (NumberExpr, AssignmentExpr) = assignParseTest("put 42 in my life", "my life", 42.0)
        let _: (StringExpr, AssignmentExpr) = assignParseTest("put \"squirrels\" into my pants", "my pants", "squirrels")
    }

    func testInput() throws {
        let testParse = { (inp: String, expLocName: String?) in
            let exprs = try! self.parse(inp)
            XCTAssertEqual(exprs.count, 1)
            let i = exprs[0] as! InputExpr
            if let elc = expLocName {
                XCTAssertEqual((i.target! as! CommonVariableNameExpr).name, elc)
            } else {
                XCTAssertNil(i.target)
            }
        }

        testParse("Listen", nil)
        testParse("Listen ", nil)
        testParse("Listen to my heart", "my heart")
    }

    func testOutput() throws {
        let testParse = { (inp: String, expLocName: String) in
            let exprs = try! self.parse(inp)
            XCTAssertEqual(exprs.count, 1)
            let o = try XCTUnwrap(exprs[0] as? OutputExpr)
            XCTAssertEqual((o.target as! CommonVariableNameExpr).name, expLocName)
        }

        try testParse("Shout my name", "my name")
        try testParse("whisper my name", "my name")
        try testParse("scream my name", "my name")
        try testParse("say my name", "my name") // Heisenberg
    }

    func testFizzBuzz() throws {
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))
        XCTAssertThrowsError(try self.parse(fizzbuzz)) { error in
            // let parser = try! Parser(lexemes: lexemes)
        }
        // XCTAssertEqual(parser.lines, 26)
    }
}
