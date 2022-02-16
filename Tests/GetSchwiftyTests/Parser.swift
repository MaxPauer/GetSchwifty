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
                XCTAssertEqual((v as! VariableNameExpr).name, e)
            }
        }

        testParse("A horse", ["a horse"])
        testParse("An  elf", ["an elf"])
        testParse("THE HOUSE", ["the house"])
        testParse("My\tlife", ["my life"])
        testParse("your Heart", ["your heart"])
        testParse("our SoCiEtY", ["our society"])
    }

    func errorTest<E>(_ inp: String,_ got: Lex.Type, _ expr: Expr.Type) -> E where E: LexemeError {
        var error: E!
        XCTAssertThrowsError(try self.parse(inp)) { (e: Error) in
            error = try! XCTUnwrap(e as? E)
            XCTAssert(type(of: error.got) == got)
            XCTAssert(type(of: error.parsing) == expr)
        }
        return error
    }

    func errorTest(_ inp: String, _ expr: Expr.Type) -> UnexpectedEOLError {
        var error: UnexpectedEOLError!
        XCTAssertThrowsError(try self.parse(inp)) { (e: Error) in
            error = try! XCTUnwrap(e as? UnexpectedEOLError)
            XCTAssert(type(of: error.parsing) == expr)
        }
        return error
    }

    func errorTest(_ inp: String, _ expr: Expr.Type) -> UnexpectedIdentifierError {
        return errorTest(inp, IdentifierLex.self, expr)
    }

    func errorTest<Expecting>(_ inp: String, _ got: Expr.Type, _ expr: Expr.Type) -> UnexpectedExprError<Expecting> {
        var error: UnexpectedExprError<Expecting>!
        XCTAssertThrowsError(try self.parse(inp)) { (e: Error) in
            error = try! XCTUnwrap(e as? UnexpectedExprError<Expecting>)
            XCTAssert(type(of: error.got) == got)
            XCTAssert(type(of: error.parsing) == expr)
        }
        return error
    }


    func testCommonVariableFailure() throws {
        let _: UnexpectedLexemeError = errorTest("A\"field\"", StringLex.self, CommonVariableNameExpr.self)
        let _: UnexpectedLexemeError = errorTest("A,field", DelimiterLex.self, CommonVariableNameExpr.self)
        let _: UnexpectedEOLError = errorTest("A\nfield", CommonVariableNameExpr.self)
        let _: UnexpectedEOLError = errorTest("A ", CommonVariableNameExpr.self)
        let _: UnexpectedEOLError = errorTest("A \n", CommonVariableNameExpr.self)
    }

    func assignParseTest<U, V, W>(_ inp: String, _ expVarName: String, _ expValue: U) -> (V,W) where U: Equatable, V: LeafExpr, V.LiteralType == U, W: AnyAssignmentExpr {
        let exprs = try! self.parse(inp)
        XCTAssertEqual(exprs.count, 1)
        let ass = exprs[0] as! W
        XCTAssertEqual((ass.target as! VariableNameExpr).name, expVarName)
        let rhs = try! XCTUnwrap(ass.value as? V)
        XCTAssertEqual(rhs.literal, expValue)
        return (rhs, ass)
    }

    func testPoeticNumberLiteral() throws {
        let _: (NumberExpr, PoeticNumberAssignmentExpr) = assignParseTest("My heaven is a halfpipe", "my heaven", 18)
        let _: (NumberExpr, PoeticNumberAssignmentExpr) = assignParseTest("My life's fucked", "my life", 6)
        let _: (NumberExpr, PoeticNumberAssignmentExpr) = assignParseTest("My life's gone", "my life", 4)
        let _: (NumberExpr, PoeticNumberAssignmentExpr) = assignParseTest("Your lies're my death", "your lies", 25)
    }

    func testPoeticNumberLiteralFailure() throws {
        let _: UnexpectedLexemeError = errorTest("My heaven is ,", DelimiterLex.self, PoeticNumberAssignmentExpr.self)
        let _: UnexpectedLexemeError = errorTest("My life's \"\"", StringLex.self, PoeticNumberAssignmentExpr.self)
        let _: UnexpectedEOLError = errorTest("My life's ", PoeticNumberAssignmentExpr.self)
    }

    func testPoeticStringLiteral() throws {
        let _: (StringExpr, PoeticStringAssignmentExpr) = assignParseTest("my father said to me A wealthy man had the things I wanted", "my father", "to me A wealthy man had the things I wanted")
    }

    func testPoeticStringLiteralFailure() throws {
        let _: UnexpectedEOLError = errorTest("my father said", PoeticStringAssignmentExpr.self)
        let _: UnexpectedEOLError = errorTest("my father said ", PoeticStringAssignmentExpr.self)
    }

    func testLetAssignment() throws {
        let _: (StringExpr, AssignmentExpr) = assignParseTest("let my life be \"GREAT\"", "my life", "GREAT")
        let _: (NumberExpr, AssignmentExpr) = assignParseTest("let my life be 42.0", "my life", 42.0)
    }

    func testPutAssignment() throws {
        let _: (NumberExpr, AssignmentExpr) = assignParseTest("put 42 in my life", "my life", 42.0)
        let _: (StringExpr, AssignmentExpr) = assignParseTest("put \"squirrels\" into my pants", "my pants", "squirrels")
    }

    func testLetPutAssignmentFailure() throws {
        let _: UnexpectedIdentifierError = errorTest("let my life into false", AssignmentExpr.self)
        let _: UnexpectedIdentifierError = errorTest("put my life be true ", AssignmentExpr.self)
    }

    func testInput() throws {
        let testParse = { (inp: String, expLocName: String?) in
            let exprs = try! self.parse(inp)
            XCTAssertEqual(exprs.count, 1)
            let i = exprs[0] as! InputExpr
            if let elc = expLocName {
                XCTAssertEqual((i.target! as! VariableNameExpr).name, elc)
            } else {
                XCTAssertNil(i.target)
            }
        }

        testParse("Listen", nil)
        testParse("Listen ", nil)
        testParse("Listen to my heart", "my heart")
    }

    func testInputFailure() throws {
        let _: UnexpectedExprError<LocationExpr> = errorTest("listen to true", BoolExpr.self, InputExpr.self)
        let _: UnexpectedEOLError = errorTest("listen to", InputExpr.self)
    }

    func testOutput() throws {
        let testParse = { (inp: String, expLocName: String) in
            let exprs = try! self.parse(inp)
            XCTAssertEqual(exprs.count, 1)
            let o = try XCTUnwrap(exprs[0] as? OutputExpr)
            XCTAssertEqual((o.target as! VariableNameExpr).name, expLocName)
        }

        try testParse("Shout my name", "my name")
        try testParse("whisper my name", "my name")
        try testParse("scream my name", "my name")
        try testParse("say my name", "my name") // Heisenberg
    }

    func testOutputFailure() throws {
        let _: UnexpectedEOLError = errorTest("Shout", OutputExpr.self)
        let _: UnexpectedLexemeError = errorTest("Shout ,", DelimiterLex.self, VanillaExpr.self)
        let _: LeafExprPushError = errorTest("Shout true \"dat\"", StringLex.self, BoolExpr.self)
    }

    func testFizzBuzz() throws {
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))
        XCTAssertThrowsError(try self.parse(fizzbuzz)) { error in
            // let parser = try! Parser(lexemes: lexemes)
        }
        // XCTAssertEqual(parser.lines, 26)
    }
}
