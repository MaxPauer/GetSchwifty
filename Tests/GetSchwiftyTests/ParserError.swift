import XCTest
@testable import GetSchwifty

final class ParserErrorTests: XCTestCase {
    func parseDiscardAll(_ inp: String) throws {
        var p = Parser(input: inp)
        while let _ = try p.next() {}
    }

    func errorTest<E>(_ inp: String,_ got: Lex.Type, _ expr: ExprBuilder.Type, _ pos: (UInt,UInt)) -> E where E: LexemeError {
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

    func errorTest(_ inp: String, _ expr: ExprBuilder.Type, _ pos: (UInt,UInt)) -> UnexpectedEOLError {
        var error: UnexpectedEOLError!
        XCTAssertThrowsError(try parseDiscardAll(inp)) { (e: Error) in
            error = try! XCTUnwrap(e as? UnexpectedEOLError)
            XCTAssert(type(of: error.parsing) == expr)
            let (line,char) = pos
            XCTAssertEqual(error.range.start, LexPos(line: line, char: char))
        }
        return error
    }

    func errorTest(_ inp: String, _ expr: ExprBuilder.Type, _ pos: (UInt,UInt)) -> UnexpectedIdentifierError {
        return errorTest(inp, IdentifierLex.self, expr, pos)
    }

    func errorTest<Expecting>(_ inp: String, _ got: ExprP.Type, _ expr: ExprBuilder.Type, _ pos: (UInt,UInt)) throws -> UnexpectedExprError<Expecting> {
        var error: Error!
        XCTAssertThrowsError(try parseDiscardAll(inp)) { (e: Error) in
            error = e
        }
        let err = try XCTUnwrap(error as? UnexpectedExprError<Expecting>)
        XCTAssert(type(of: err.got) == got)
        XCTAssert(type(of: err.parsing) == expr)
        let (line,char) = pos
        XCTAssertEqual(err.range.start, LexPos(line: line, char: char))
        return err
    }

    func testCommonVariableFailure() throws {
        let _: UnexpectedLexemeError = errorTest("A\"field\"", StringLex.self, CommonVariableNameExprBuilder.self, (1,1))
        let _: UnexpectedLexemeError = errorTest("A,field", DelimiterLex.self, CommonVariableNameExprBuilder.self, (1,1))
        let _: UnexpectedEOLError = errorTest("A\nfield", CommonVariableNameExprBuilder.self, (1,1))
        let _: UnexpectedEOLError = errorTest("A ", CommonVariableNameExprBuilder.self, (1,2))
        let _: UnexpectedEOLError = errorTest("A \n", CommonVariableNameExprBuilder.self, (1,2))
    }

    func testPoeticNumberLiteralFailure() throws {
        let _: UnexpectedLexemeError = errorTest("My heaven is ,", DelimiterLex.self, PoeticNumberAssignmentExprBuilder.self, (1,13))
        let _: UnexpectedLexemeError = errorTest("My life's \"\"", StringLex.self, PoeticNumberAssignmentExprBuilder.self, (1,10))
    }

    func testLetPutAssignmentFailure() throws {
        let _: UnexpectedIdentifierError = errorTest("let my life into false", AssignmentExprBuilder.self, (1,12))
        let _: UnexpectedIdentifierError = errorTest("put my life be true ", AssignmentExprBuilder.self, (1,12))
        let _: UnexpectedIdentifierError = errorTest("let ' be nothing", AssignmentExprBuilder.self, (1,6))
        let _: UnexpectedIdentifierError = errorTest("let ''' be nothing", AssignmentExprBuilder.self, (1,8))
    }

    func testInputFailure() throws {
        let _: UnexpectedExprError<LocationExprP> = try errorTest("listen to true", BoolExpr.self, InputExprBuilder.self, (1,14))
        let _: UnexpectedExprError<LocationExprP> = try errorTest("listen to", NopExpr.self, InputExprBuilder.self, (1,9))
    }

    func testOutputFailure() throws {
        let _: UnexpectedExprError<ValueExprP> = try errorTest("Shout", NopExpr.self, OutputExprBuilder.self, (1,5))
        let _: UnexpectedLexemeError = errorTest("Shout ,", DelimiterLex.self, OutputExprBuilder.self, (1,6))
        let _: LeafExprPushError = errorTest("Shout true \"dat\"", StringLex.self, BoolExprBuilder.self, (1,11))
    }

    func testIncDecrementFailure() throws {
        let _: UnexpectedExprError<LocationExprP> = try errorTest("Knock", NopExpr.self, CrementExprBuilder.self, (1,5))
        let _: UnexpectedExprError<LocationExprP> = try errorTest("Build", NopExpr.self, CrementExprBuilder.self, (1,5))
        let _: UnexpectedIdentifierError = errorTest("Knock me up", CrementExprBuilder.self, (1,9))
        let _: UnexpectedIdentifierError = errorTest("Build it down", CrementExprBuilder.self, (1,9))
        let _: UnexpectedLexemeError = errorTest("Knock me down at", IdentifierLex.self, CrementExprBuilder.self, (1,14))
        let _: UnexpectedLexemeError = errorTest("Build it up 0.5", NumberLex.self, CrementExprBuilder.self, (1,12))
    }
}
