import XCTest
@testable import GetSchwifty

final class ParserErrorTests: XCTestCase {
    func parseDiscardAll(_ inp: String) throws {
        var p = Parser(input: inp)
        while let _ = try p.next() {}
    }

    func errorTest<E>(_ inp: String,_ got: Lex.Type, _ expr: Expr.Type, _ pos: (UInt,UInt)) -> E where E: LexemeError {
        var error: E!
        XCTAssertThrowsError(try parseDiscardAll(inp)) { (e: Error) in
            error = try! XCTUnwrap(e as? E)
            XCTAssert(type(of: error.got) == got)
            XCTAssert(type(of: error.parsing) == expr)
            let (line,char) = pos
            XCTAssertEqual(error.range.start, LexPos(line: line, char: char))
        }
        return error
    }

    func errorTest(_ inp: String, _ expr: Expr.Type, _ pos: (UInt,UInt)) -> UnexpectedEOLError {
        var error: UnexpectedEOLError!
        XCTAssertThrowsError(try parseDiscardAll(inp)) { (e: Error) in
            error = try! XCTUnwrap(e as? UnexpectedEOLError)
            XCTAssert(type(of: error.parsing) == expr)
            let (line,char) = pos
            XCTAssertEqual(error.range.start, LexPos(line: line, char: char))
        }
        return error
    }

    func errorTest(_ inp: String, _ expr: Expr.Type, _ pos: (UInt,UInt)) -> UnexpectedIdentifierError {
        return errorTest(inp, IdentifierLex.self, expr, pos)
    }

    func errorTest<Expecting>(_ inp: String, _ got: Expr.Type, _ expr: Expr.Type, _ pos: (UInt,UInt)) -> UnexpectedExprError<Expecting> {
        var error: UnexpectedExprError<Expecting>!
        XCTAssertThrowsError(try parseDiscardAll(inp)) { (e: Error) in
            error = try! XCTUnwrap(e as? UnexpectedExprError<Expecting>)
            XCTAssert(type(of: error.got) == got)
            XCTAssert(type(of: error.parsing) == expr)
            let (line,char) = pos
            XCTAssertEqual(error.range.start, LexPos(line: line, char: char))
        }
        return error
    }

    func testCommonVariableFailure() throws {
        let _: UnexpectedLexemeError = errorTest("A\"field\"", StringLex.self, CommonVariableNameExpr.self, (1,1))
        let _: UnexpectedLexemeError = errorTest("A,field", DelimiterLex.self, CommonVariableNameExpr.self, (1,1))
        let _: UnexpectedEOLError = errorTest("A\nfield", CommonVariableNameExpr.self, (1,1))
        let _: UnexpectedEOLError = errorTest("A ", CommonVariableNameExpr.self, (1,2))
        let _: UnexpectedEOLError = errorTest("A \n", CommonVariableNameExpr.self, (1,2))
    }

    func testPoeticNumberLiteralFailure() throws {
        let _: UnexpectedLexemeError = errorTest("My heaven is ,", DelimiterLex.self, PoeticNumberAssignmentExpr.self, (1,13))
        let _: UnexpectedLexemeError = errorTest("My life's \"\"", StringLex.self, PoeticNumberAssignmentExpr.self, (1,10))
        let _: UnexpectedEOLError = errorTest("My life's ", PoeticNumberAssignmentExpr.self, (1,10))
    }

    func testLetPutAssignmentFailure() throws {
        let _: UnexpectedIdentifierError = errorTest("let my life into false", AssignmentExpr.self, (1,12))
        let _: UnexpectedIdentifierError = errorTest("put my life be true ", AssignmentExpr.self, (1,12))
        let _: UnexpectedIdentifierError = errorTest("let ' be nothing", AssignmentExpr.self, (1,6))
        let _: UnexpectedIdentifierError = errorTest("let ''' be nothing", AssignmentExpr.self, (1,8))
    }

    func testInputFailure() throws {
        let _: UnexpectedExprError<LocationExpr> = errorTest("listen to true", BoolExpr.self, InputExpr.self, (1,10))
        let _: UnexpectedEOLError = errorTest("listen to", InputExpr.self, (1,9))
    }

    func testOutputFailure() throws {
        let _: UnexpectedEOLError = errorTest("Shout", OutputExpr.self, (1,5))
        let _: UnexpectedLexemeError = errorTest("Shout ,", DelimiterLex.self, OutputExpr.self, (1,6))
        let _: LeafExprPushError = errorTest("Shout true \"dat\"", StringLex.self, BoolExpr.self, (1,11))
    }

    func testIncDecrementFailure() throws {
        let _: UnexpectedEOLError = errorTest("Knock", CrementExpr.self, (1,5))
        let _: UnexpectedEOLError = errorTest("Build", CrementExpr.self, (1,5))
        let _: UnexpectedIdentifierError = errorTest("Knock me up", CrementExpr.self, (1,9))
        let _: UnexpectedIdentifierError = errorTest("Build it down", CrementExpr.self, (1,9))
        let _: UnexpectedLexemeError = errorTest("Knock me down at", IdentifierLex.self, CrementExpr.self, (1,14))
        let _: UnexpectedLexemeError = errorTest("Build it up 0.5", NumberLex.self, CrementExpr.self, (1,12))
    }
}
