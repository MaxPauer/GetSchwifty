import XCTest
@testable import GetSchwifty

fileprivate extension ValueExpr {
    var string: String? {
        guard case .string(let s) = self else { return nil }
        return s
    }
    var number: Float? {
        guard case .number(let f) = self else { return nil }
        return f
    }
}

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

    func testCommonVariableFailure() {
        let testParse = { (inp: String, err: PartialParserError.Type, got: Lex.Type?, exp: Lex.Type) in
            XCTAssertThrowsError(try self.parse(inp)) { (e: Error) in
                let error = e as! ParserError
                XCTAssert(type(of: error.partialErr) == err)
                switch error.partialErr {
                case let err as UnexpectedLexemeError:
                    XCTAssert(err.expected == exp)
                    XCTAssert(type(of: err.got) == got!)
                case let err as UnexpectedEOFError:
                    XCTAssert(err.expected == exp)
                default:
                    XCTFail("Unexpected Error type")
                }
            }
        }

        try! testParse("A\"field\"", UnexpectedLexemeError.self, StringLex.self, WhitespaceLex.self)
        try! testParse("A,field", UnexpectedLexemeError.self, DelimiterLex.self, WhitespaceLex.self)
        try! testParse("A\nfield", UnexpectedLexemeError.self, NewlineLex.self, WhitespaceLex.self)
        try! testParse("A ", UnexpectedEOFError.self, nil, IdentifierLex.self)
        try! testParse("A \n", UnexpectedLexemeError.self, NewlineLex.self, IdentifierLex.self)
    }

    func testPoeticNumberLiteral() throws {
        let testParse = { (inp: String, expVarName: String, expVarValue: Float) in
            let exprs = try! self.parse(inp)
            XCTAssertEqual(exprs.count, 1)
            let ass = exprs[0] as! AssignmentExpr
            XCTAssertEqual(ass.lhs!.name, expVarName)
            let rhsVal = try! XCTUnwrap((ass.rhs! as? ValueExpr)?.number)
            XCTAssertEqual(rhsVal, expVarValue)
        }
        testParse("My heaven is a halfpipe", "my heaven", 18.0)
    }

    func testPoeticStringLiteral() throws {
        let testParse = { (inp: String, expVarName: String, expVarValue: String) in
            let exprs = try! self.parse(inp)
            XCTAssertEqual(exprs.count, 1)
            let ass = exprs[0] as! AssignmentExpr
            XCTAssertEqual(ass.lhs!.name, expVarName)
            let rhsVal = try! XCTUnwrap((ass.rhs! as? ValueExpr)?.string)
            XCTAssertEqual(rhsVal, expVarValue)
        }
        testParse("my father said to me A wealthy man had the things I wanted", "my father", "to me A wealthy man had the things I wanted")
    }

    func testLetAssignment() throws {
        func testParse(_ inp: String, _ expVarName: String, _ expValue: Float) {
            let exprs = try! self.parse(inp)
            XCTAssertEqual(exprs.count, 1)
            let ass = exprs[0] as! AssignmentExpr
            XCTAssertEqual(ass.lhs!.name, expVarName)
            let rhsVal = try! XCTUnwrap(ass.rhs! as? ValueExpr)
            switch rhsVal {
            case .number(let n): XCTAssert(expValue == n)
            default: XCTFail()
            }
        }
        func testParse(_ inp: String, _ expVarName: String, _ expValue: String) {
            let exprs = try! self.parse(inp)
            XCTAssertEqual(exprs.count, 1)
            let ass = exprs[0] as! AssignmentExpr
            XCTAssertEqual(ass.lhs!.name, expVarName)
            let rhsVal = try! XCTUnwrap(ass.rhs! as? ValueExpr)
            switch rhsVal {
            case .string(let s): XCTAssert(expValue == s)
            default: XCTFail()
            }
        }
        testParse("let my life be \"GREAT\"", "my life", "GREAT")
        testParse("let my life be 42.0", "my life", 42.0)
    }

    func testFizzBuzz() throws {
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))
        XCTAssertThrowsError(try self.parse(fizzbuzz)) { error in
            // let parser = try! Parser(lexemes: lexemes)
        }
        // XCTAssertEqual(parser.lines, 26)
    }
}
