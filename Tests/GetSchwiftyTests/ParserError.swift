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
            XCTAssertEqual(error.startPos, LexPos(line: line, char: char))
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
        XCTAssertEqual(err.startPos, LexPos(line: line, char: char))
        return err
    }

    func testCommonVariableFailure() throws {
        let _: UnexpectedLexemeError = errorTest("A\"field\"", StringLex.self, CommonVariableNameExprBuilder.self, (1,1))
        let _: UnexpectedLexemeError = errorTest("A,field", DelimiterLex.self, CommonVariableNameExprBuilder.self, (1,1))
        let _: UnexpectedLexemeError = errorTest("A\nfield", NewlineLex.self, CommonVariableNameExprBuilder.self, (1,1))
        let _: UnexpectedLexemeError = errorTest("A ", NewlineLex.self, CommonVariableNameExprBuilder.self, (1,2))
        let _: UnexpectedLexemeError = errorTest("A \n", NewlineLex.self, CommonVariableNameExprBuilder.self, (1,2))
    }

    func testPoeticNumberLiteralFailure() throws {
        let _: UnexpectedLexemeError = errorTest("My heaven is 1.5", NumberLex.self, PoeticNumberishAssignmentExprBuilder.self, (1,13))
        let _: UnexpectedLexemeError = errorTest("My life's \"\"", StringLex.self, PoeticNumberishAssignmentExprBuilder.self, (1,10))
        let _: UnexpectedExprError<ValueExprP> = try errorTest("My life's ", NopExpr.self, PoeticNumberishAssignmentExprBuilder.self, (1,9))
    }

    func testLetPutAssignmentFailure() throws {
        let _: UnexpectedIdentifierError = errorTest("let my life into false", AssignmentExprBuilder.self, (1,12))
        let _: UnexpectedIdentifierError = errorTest("put my life be true ", AssignmentExprBuilder.self, (1,12))
        let _: UnexpectedLexemeError = errorTest("let ' be nothing", IdentifierLex.self, AssignmentExprBuilder.self, (1,6))
        let _: UnexpectedLexemeError = errorTest("let ''' be nothing", IdentifierLex.self, AssignmentExprBuilder.self, (1,8))
    }

    func testInputFailure() throws {
        let _: UnexpectedExprError<LocationExprP> = try errorTest("listen to true", BoolExpr.self, InputExprBuilder.self, (1,10))
        let _: UnexpectedExprError<LocationExprP> = try errorTest("listen to", NopExpr.self, InputExprBuilder.self, (1,9))
    }

    func testOutputFailure() throws {
        let _: UnexpectedExprError<ValueExprP> = try errorTest("Shout", NopExpr.self, OutputExprBuilder.self, (1,5))
        let _: UnexpectedLexemeError = errorTest("Shout ,", DelimiterLex.self, OutputExprBuilder.self, (1,6))
        let _: UnexpectedLexemeError = errorTest("Shout true \"dat\"", StringLex.self, BoolExprBuilder.self, (1,11))
    }

    func testIndexingFailure() throws {
        let _: UnexpectedExprError<ValueExprP> = try errorTest("him at", NopExpr.self, IndexingLocationExprBuilder.self, (1,6))
        let _: UnexpectedExprError<ValueExprP> = try errorTest("her at ,", NopExpr.self, IndexingLocationExprBuilder.self, (1,7))
        let _: UnexpectedLexemeError = errorTest("5 at 5", IdentifierLex.self, NumberExprBuilder.self, (1,2))
    }

    func testIncDecrementFailure() throws {
        let _: UnexpectedExprError<LocationExprP> = try errorTest("Knock", NopExpr.self, CrementExprBuilder.self, (1,5))
        let _: UnexpectedExprError<LocationExprP> = try errorTest("Build", NopExpr.self, CrementExprBuilder.self, (1,5))
        let _: UnexpectedIdentifierError = errorTest("Knock me up", CrementExprBuilder.self, (1,9))
        let _: UnexpectedIdentifierError = errorTest("Build it down", CrementExprBuilder.self, (1,9))
        let _: UnexpectedLexemeError = errorTest("Knock me down at", IdentifierLex.self, CrementExprBuilder.self, (1,14))
        let _: UnexpectedLexemeError = errorTest("Build it up 0.5", NumberLex.self, CrementExprBuilder.self, (1,12))
    }

    func testPushPopFailure() throws {
        let _: UnexpectedExprError<LocationExprP> = try errorTest("rock", NopExpr.self, PushExprBuilder.self, (1,4))
        let _: UnexpectedExprError<ValueExprP> = try errorTest("push it with", NopExpr.self, PushExprBuilder.self, (1,12))
        let _: UnexpectedExprError<LocationExprP> = try errorTest("roll", NopExpr.self, PopExprBuilder.self, (1,4))
        let _: UnexpectedExprError<LocationExprP> = try errorTest("pop 5", NumberExpr.self, PopExprBuilder.self, (1,4))
    }

    func testArithFailure() throws {
        let _: UnexpectedExprError<ValueExprP> = try errorTest("1 with ", NopExpr.self, BiArithExprBuilder.self, (1,7))
        let _: UnexpectedLexemeError = errorTest("1 with 5 is greater 4", NumberLex.self, BiArithExprBuilder.self, (1,20))
        let _: UnexpectedIdentifierError = errorTest("1 with 5 is greater as 4", BiArithExprBuilder.self, (1,20))
        let _: UnexpectedLexemeError = errorTest("1 with 5 is than 4", NumberLex.self, VariableNameExprBuilder.self, (1,17))
        let _: UnexpectedIdentifierError = errorTest("1 with 5 is as greater 4", BiArithExprBuilder.self, (1,15))
        let _: UnexpectedLexemeError = errorTest("1 with 5 is 4 greater", IdentifierLex.self, NumberExprBuilder.self, (1,14))
    }

    func testListFailure() throws {
        let _: UnexpectedLexemeError = errorTest("5, 6 & 7, and 8, 9 & and 10", NumberLex.self, VariableNameExprBuilder.self, (1,25))
        let _: UnexpectedExprError<ValueExprP> = try errorTest("5, 6 & 7, and 8, ", NopExpr.self, ListExprBuilder.self, (1,15))
    }

    func testLetWithAssignmentFailure() throws {
        let _: UnexpectedExprError<ValueExprP> = try errorTest("let the devil be between ", NopExpr.self, AssignmentExprBuilder.self, (1,25))
        let _: UnexpectedLexemeError = errorTest("let the devil be 8 between", IdentifierLex.self, AssignmentExprBuilder.self, (1,19))
    }
}
