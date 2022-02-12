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
    func testCommonVariable() throws {
        let testParse = { (inp: String, exp: [String]) in
            let p = try! Parser(lexemes: lex(inp))
            XCTAssertEqual(p.rootExpr.children.count, exp.count)
            for (v, e) in zip(p.rootExpr.children, exp) {
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
        let testParse = { (inp: String, part: PartialParserError) in
            let l = lex(inp)
            XCTAssertThrowsError(try Parser(lexemes: l)) { error in
                XCTAssertEqual(error as! ParserError, ParserError(onLine: 1, partialErr: part))
            }
        }

        try! testParse("A\"field\"", UnexpectedLexemeError(got: .string("field"), expected:Lexeme.whitespace))
        try! testParse("A,field", UnexpectedLexemeError(got: .delimiter, expected:Lexeme.whitespace))
        try! testParse("A\nfield", UnexpectedLexemeError(got: .newline, expected:Lexeme.whitespace))
        try! testParse("A ", UnexpectedEOFError(expected: AnyLexeme.word))
        try! testParse("A \n", UnexpectedLexemeError(got: .newline, expected:AnyLexeme.word))
    }

    func testPoeticNumberLiteral() throws {
        let testParse = { (inp: String, expVarName: String, expVarValue: Float) in
            let l = lex(inp)
            let p = try! Parser(lexemes: l)
            let exprs = p.rootExpr.children
            XCTAssertEqual(exprs.count, 1)
            let ass = exprs[0] as! AssignmentExpr
            XCTAssertEqual(ass.lhs!.name, expVarName)
            let rhsVal = try! XCTUnwrap(ass.rhs!.number)
            XCTAssertEqual(rhsVal, expVarValue)
        }
        testParse("My heaven is a halfpipe", "my heaven", 18.0)
    }

    func testFizzBuzz() throws {
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))
        let lexemes = lex(fizzbuzz)
        XCTAssertThrowsError(try Parser(lexemes: lexemes)) { error in
            // let parser = try! Parser(lexemes: lexemes)
        }
        // XCTAssertEqual(parser.lines, 26)
    }
}
