import XCTest
@testable import GetSchwifty

final class EvalTests: XCTestCase {
    func errorTest<T>(_ inp: String, _ pos: (UInt,UInt)) throws -> T where T: RuntimeError {
        var c = MainEvalContext(input: inp)
        var error: Error?
        XCTAssertThrowsError(try c.run()) { (e: Error) in
            error = e
        }
        let err = try XCTUnwrap(error as? T)
        let (line, char) = pos
        XCTAssertEqual(err.startPos, LexPos(line: line, char: char))
        return err
    }

    func assertVariable<T>(_ c: EvalContext, _ v: String, _ val: T) throws where T: Equatable {
        let vval = try XCTUnwrap(c.variables[v] as? T)
        XCTAssertEqual(vval, val)
    }

    @discardableResult
    func step(_ c: inout MainEvalContext, _ f: (MainEvalContext) throws -> Void = {_ in}) throws -> Bool {
        let didStep = try XCTUnwrap(c.step())
        try f(c)
        return didStep
    }

    func testBoolAssignment() throws {
        var c = MainEvalContext(input: "put true into my world\nlet my house be false\nput my world into my house")
        try step(&c) {
            try assertVariable($0, "my world", true)
        }
        try step(&c) {
            try assertVariable($0, "my world", true)
            try assertVariable($0, "my house", false)
        }
        try step(&c) {
            try assertVariable($0, "my world", true)
            try assertVariable($0, "my house", true)
        }
        XCTAssertTrue(try step(&c))
        XCTAssertFalse(try step(&c))
    }

    func testPoeticPronounAssignment() throws {
        var c = MainEvalContext(input: "(when i was 17) my father said to me A wealthy man had the things I wanted\nhe is nothing\nit is beating like a jungle drum")
        try step(&c) {
            try assertVariable($0, "my father", "to me A wealthy man had the things I wanted")
        }
        try step(&c) {
            try assertVariable($0, "my father", NullExpr.NullValue())
        }
        try step(&c) {
            try assertVariable($0, "my father", 74164.0)
        }
    }

    func testBooleanLogicAssignment() throws {
        var c = MainEvalContext(input: "let my life be not mysterious\nlet it be right and wrong\nlet it be 5 is greater than 4\nlet it be 5 ain't 5\nlet it be 5 is as great as 1")
        try step(&c) {
            try assertVariable($0, "my life", true)
        }
        try step(&c) {
            try assertVariable($0, "my life", false)
        }
        try step(&c) {
            try assertVariable($0, "my life", true)
        }
        try step(&c) {
            try assertVariable($0, "my life", false)
        }
        try step(&c) {
            try assertVariable($0, "my life", true)
        }
    }

    func testErrors() throws {
        let _: VariableReadError = try errorTest("put my heart into my soul", (1,4))
        let _: PronoundUsedBeforeAssignmentError = try errorTest("it is nothing", (1,0))
        let _: NonComparableExprError = try errorTest("let my life be 5 is greater than \"4\"", (1,32))
    }
}
