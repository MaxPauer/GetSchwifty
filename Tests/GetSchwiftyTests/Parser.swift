import XCTest
@testable import GetSchwifty

extension ParserError: Equatable {
    public static func==(lhs: ParserError, rhs: ParserError) -> Bool {
        guard lhs.onLine == rhs.onLine else { return false }
        return lhs.partialErr.description == rhs.partialErr.description
    }
}

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

    // func testCommonVariableFailure() {
    //     let testParse = { (inp: String, err: PartialParserError.Type, got: Lex.Type?, exp: Lex.Type) in
    //         XCTAssertThrowsError(try self.parse(inp)) { (e: Error) in
    //             let error = e as! ParserError
    //             XCTAssert(type(of: error.partialErr) == err)
    //             switch error.partialErr {
    //             case let err as UnexpectedLexemeError:
    //                 XCTAssert(err.expected == exp)
    //                 XCTAssert(type(of: err.got) == got!)
    //             case let err as UnexpectedEOFError:
    //                 XCTAssert(err.expected == exp)
    //             default:
    //                 XCTFail("Unexpected Error type")
    //             }
    //         }
    //     }

    //     try! testParse("A\"field\"", UnexpectedLexemeError.self, StringLex.self, WhitespaceLex.self)
    //     try! testParse("A,field", UnexpectedLexemeError.self, DelimiterLex.self, WhitespaceLex.self)
    //     try! testParse("A\nfield", UnexpectedLexemeError.self, NewlineLex.self, WhitespaceLex.self)
    //     try! testParse("A ", UnexpectedEOFError.self, nil, IdentifierLex.self)
    //     try! testParse("A \n", UnexpectedLexemeError.self, NewlineLex.self, IdentifierLex.self)
    // }

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

    func testFizzBuzz() throws {
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))
        XCTAssertThrowsError(try self.parse(fizzbuzz)) { error in
            // let parser = try! Parser(lexemes: lexemes)
        }
        // XCTAssertEqual(parser.lines, 26)
    }
}
