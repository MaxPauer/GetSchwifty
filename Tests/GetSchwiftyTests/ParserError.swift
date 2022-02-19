import XCTest
@testable import GetSchwifty

final class ParserErrorTests: XCTestCase {
    func parseDiscardAll(_ inp: String) throws {
        var p = Parser(input: inp)
        while let _ = try p.next() {}
    }

    func errorTest<E>(_ inp: String,_ got: Lex.Type, _ expr: Expr.Type) -> E where E: LexemeError {
        var error: E!
        XCTAssertThrowsError(try parseDiscardAll(inp)) { (e: Error) in
            error = try! XCTUnwrap(e as? E)
            XCTAssert(type(of: error.got) == got)
            XCTAssert(type(of: error.parsing) == expr)
        }
        return error
    }

    func errorTest(_ inp: String, _ expr: Expr.Type) -> UnexpectedEOLError {
        var error: UnexpectedEOLError!
        XCTAssertThrowsError(try parseDiscardAll(inp)) { (e: Error) in
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
        XCTAssertThrowsError(try parseDiscardAll(inp)) { (e: Error) in
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

    func testPoeticNumberLiteralFailure() throws {
        let _: UnexpectedLexemeError = errorTest("My heaven is ,", DelimiterLex.self, PoeticNumberAssignmentExpr.self)
        let _: UnexpectedLexemeError = errorTest("My life's \"\"", StringLex.self, PoeticNumberAssignmentExpr.self)
        let _: UnexpectedEOLError = errorTest("My life's ", PoeticNumberAssignmentExpr.self)
    }

    func testLetPutAssignmentFailure() throws {
        let _: UnexpectedIdentifierError = errorTest("let my life into false", AssignmentExpr.self)
        let _: UnexpectedIdentifierError = errorTest("put my life be true ", AssignmentExpr.self)
        let _: UnexpectedIdentifierError = errorTest("let ' be nothing", AssignmentExpr.self)
        let _: UnexpectedIdentifierError = errorTest("let ''' be nothing", AssignmentExpr.self)
    }

    func testInputFailure() throws {
        let _: UnexpectedExprError<LocationExpr> = errorTest("listen to true", BoolExpr.self, InputExpr.self)
        let _: UnexpectedEOLError = errorTest("listen to", InputExpr.self)
    }

    func testOutputFailure() throws {
        let _: UnexpectedEOLError = errorTest("Shout", OutputExpr.self)
        let _: UnexpectedLexemeError = errorTest("Shout ,", DelimiterLex.self, VanillaExpr.self)
        let _: LeafExprPushError = errorTest("Shout true \"dat\"", StringLex.self, BoolExpr.self)
    }
}
