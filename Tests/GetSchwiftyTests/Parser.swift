import XCTest
@testable import GetSchwifty

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
            XCTAssertEqual(p.exprs.count, exp.count)
            for (v, e) in zip(p.exprs, exp) {
                XCTAssertEqual((v as! CommonVariableName).name, e)
            }
        }

        testParse("A horse", ["a horse"])
        testParse("An  elf", ["an elf"])
        testParse("THE HOUSE", ["the house"])
        testParse("My\tlife", ["my life"])
        testParse("your Heart", ["your heart"])
        testParse("our SoCiEtY", ["our society"])
        testParse("your SoCiEtY my life", ["your society", "my life"])
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

    func testFizzBuzz() throws {
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))
        let lexemes = lex(fizzbuzz)
        let parser = try! Parser(lexemes: lexemes)
        XCTAssertEqual(parser.lines, 26)
    }
}
