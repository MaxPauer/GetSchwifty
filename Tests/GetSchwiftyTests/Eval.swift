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

    func assertDict(_ c: EvalContext, _ v: String, _ val: [AnyHashable: Any]) throws {
        let vval = try XCTUnwrap(c.variables[v] as? RockstarArray)
        XCTAssertEqual(vval.count, val.count)
        for (rk, rv) in val {
            let v = try XCTUnwrap(rv as? AnyHashable)
            let vv = try XCTUnwrap(vval[rk] as? AnyHashable)
            XCTAssertEqual(v, vv)
        }
    }

    func assertArray(_ c: EvalContext, _ v: String, _ val: [AnyHashable]) throws {
        let vval = try XCTUnwrap(c.variables[v] as? [AnyHashable])
        XCTAssertEqual(vval.count, val.count)
        for (l,r) in zip(val, vval) {
            XCTAssertEqual(l,r)
        }
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
            try assertVariable($0, "my father", Rockstar.null)
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

    func testMath() throws {
        var c = MainEvalContext(input: "let my life be 5 minus 3\nlet it be 2 plus \"foo\"\nlet it be \"foo\" with \"fighters\"\nlet it be 10 over 2")
        try step(&c) {
            try assertVariable($0, "my life", 2.0)
        }
        try step(&c) {
            try assertVariable($0, "my life", "2.0foo")
        }
        try step(&c) {
            try assertVariable($0, "my life", "foofighters")
        }
        try step(&c) {
            try assertVariable($0, "my life", 5.0)
        }
    }

    func testMathRound() throws {
        var c = MainEvalContext(input: "let my life be 5.3\nturn it around\nlet my life be 5.3\nturn it up\nlet my life be 5.3\nturn it down\n")
        try step(&c) {
            try assertVariable($0, "my life", 5.3)
        }
        try step(&c) {
            try assertVariable($0, "my life", 5.0)
        }
        try step(&c) {
            try assertVariable($0, "my life", 5.3)
        }
        try step(&c) {
            try assertVariable($0, "my life", 6.0)
        }
        try step(&c) {
            try assertVariable($0, "my life", 5.3)
        }
        try step(&c) {
            try assertVariable($0, "my life", 5.0)
        }
    }

    func testInOut() throws {
        var result: Any?
        var c = MainEvalContext(input: "listen to your heart\nshout it", stdin: {"noice"}, stdout: { result = $0 })
        try c.run()
        let r = try XCTUnwrap(result as? String)
        XCTAssertEqual(r, "noice")
    }

    func testSwiftFun() throws {
        var result: Any?
        var c = MainEvalContext(input: "put \"hallo\" into my world\nlisten to my life\nshout my life taking \"hallo\", my world",
                                stdin: { { (args: [Any]) -> Any in "\(args[0]) \(args[1])" } },
                               stdout: { result = $0 })
        try c.run()
        let r = try XCTUnwrap(result as? String)
        XCTAssertEqual(r, "hallo hallo")
    }

    func testArrays() throws {
        var c = MainEvalContext(input: """
            put 5 into my world
            let my world at 1 be 4
            let my world at 0 be "nice"
            let my world at "hello" be "cool"
            put my world into my soul
            let my world at 100 be "bad"
            put my world into my soul
            let my heart be my world at "hello"
            let foo be 1,2,3,4
            let bar be my world at 2
            """)
        try step(&c) {
            try assertVariable($0, "my world", 5.0)
        }
        try step(&c) {
            try assertDict($0, "my world", [0: 5.0, 1: 4.0])
        }
        try step(&c) {
            try assertDict($0, "my world", [0: "nice", 1: 4.0])
        }
        try step(&c) {
            try assertDict($0, "my world", [0: "nice", 1: 4.0, "hello": "cool"])
        }
        try step(&c) {
            try assertVariable($0, "my soul", 2.0)
        }
        _ = try c.step()
        try step(&c) {
            try assertVariable($0, "my soul", 101.0)
        }
        try step(&c) {
            try assertVariable($0, "my heart", "cool")
        }
        try step(&c) {
            try assertArray($0, "foo", [1.0,2.0,3.0,4.0])
        }
        try step(&c) {
            try assertVariable($0, "bar", Rockstar.mysterious)
        }
    }

    func testPop() throws {
        var c = MainEvalContext(input: """
            put 5 into my world
            let my world at 1 be 4
            let my world at 2 be "nice"
            let my world at "xyz" be "fool"
            let my world at "hello" be "cool"
            let my soul be pop my world
            let my soul be pop my world
            let my soul be pop my world
            let my soul be pop my world
            let my soul be pop my world
            let my soul be pop my world
            """)
        try step(&c) {
            try assertVariable($0, "my world", 5.0)
        }
        try step(&c) {
            try assertDict($0, "my world", [0: 5.0, 1: 4.0])
        }
        try step(&c) {
            try assertDict($0, "my world", [0: 5.0, 1: 4.0, 2: "nice"])
        }
        try step(&c) {
            try assertDict($0, "my world", [0: 5.0, 1: 4.0, 2: "nice", "xyz": "fool"])
        }
        try step(&c) {
            try assertDict($0, "my world", [0: 5.0, 1: 4.0, 2: "nice", "hello": "cool", "xyz": "fool"])
        }
        try step(&c) {
            try assertVariable($0, "my soul", 5.0)
            try assertDict($0, "my world", [1: 4.0, 2: "nice", "hello": "cool", "xyz": "fool"])
        }
        try step(&c) {
            try assertVariable($0, "my soul", 4.0)
            try assertDict($0, "my world", [2: "nice", "hello": "cool", "xyz": "fool"])
        }
        try step(&c) {
            try assertVariable($0, "my soul", "nice")
            try assertDict($0, "my world", ["hello": "cool", "xyz": "fool"])
        }
        try step(&c) {
            try assertVariable($0, "my soul", "fool")
            try assertDict($0, "my world", ["hello": "cool"])
        }
        try step(&c) {
            try assertVariable($0, "my soul", "cool")
            try assertDict($0, "my world", [:])
        }
        try step(&c) {
            try assertVariable($0, "my soul", Rockstar.null)
            try assertDict($0, "my world", [:])
        }
    }

    func testPush() throws {
        var c = MainEvalContext(input: """
            put 5 into my world
            rock my world
            put my world into my soul
            rock my world like a hurricane
            put my world into my soul
            rock my world with 2,3,"monkey" & 4
            put my world into my soul
            let my world at 101 be 200
            put my world into my soul
            rock my world with my soul
            roll my world
            roll my world into my soul
            let my soul be roll my world with 2
            """)
        try step(&c) {
            try assertVariable($0, "my world", 5.0)
        }
        try step(&c) {
            try assertDict($0, "my world", [:])
        }
        try step(&c) {
            try assertVariable($0, "my soul", 0.0)
        }
        try step(&c) {
            try assertDict($0, "my world", [0: 19])
        }
        try step(&c) {
            try assertVariable($0, "my soul", 1.0)
        }
        try step(&c) {
            try assertDict($0, "my world", [0: 19, 1: 2, 2: 3, 3: "monkey", 4: 4])
        }
        try step(&c) {
            try assertVariable($0, "my soul", 5.0)
        }
        try step(&c) {
            try assertDict($0, "my world", [0: 19, 1: 2, 2: 3, 3: "monkey", 4: 4, 101: 200])
        }
        try step(&c) {
            try assertVariable($0, "my soul", 102.0)
        }
        try step(&c) {
            try assertDict($0, "my world", [0: 19, 1: 2, 2: 3, 3: "monkey", 4: 4, 101: 200, 102: 102])
        }
        try step(&c) {
            try assertDict($0, "my world", [1: 2, 2: 3, 3: "monkey", 4: 4, 101: 200, 102: 102])
        }
        try step(&c) {
            try assertVariable($0, "my soul", 2.0)
            try assertDict($0, "my world", [2: 3, 3: "monkey", 4: 4, 101: 200, 102: 102])
        }
        try step(&c) {
            try assertVariable($0, "my soul", 5.0)
            try assertDict($0, "my world", [3: "monkey", 4: 4, 101: 200, 102: 102])
        }
    }

    func testSplit() throws {
        var x = MainEvalContext(input: """
            cut "my life" into pieces
            cut "my life" into pieces with " "
            let my life be "123"
            cut my life
            let my life be "1,2,3"
            cut my life with ","
            """)
        try step(&x) {
            try assertDict($0, "pieces", [0: "m", 1: "y", 2: " ", 3: "l", 4: "i", 5: "f", 6: "e"])
        }
        try step(&x) {
            try assertDict($0, "pieces", [0: "my", 1: "life"])
        }
        _ = try x.step()
        try step(&x) {
            try assertDict($0, "my life", [0: "1", 1: "2", 2: "3"])
        }
        _ = try x.step()
        try step(&x) {
            try assertDict($0, "my life", [0: "1", 1: "2", 2: "3"])
        }
    }

    func testJoin() throws {
        var x = MainEvalContext(input: """
            let my life be "123"
            cut my life
            join my life
            let my life be "1,2,3"
            cut my life into pieces with ","
            join pieces into my life with " or "
            rock my house
            rock my house with "a","b"
            join my house with "c"
            """)
        _ = try x.step()
        _ = try x.step()
        try step(&x) {
            try assertVariable($0, "my life", "123")
        }
        _ = try x.step()
        _ = try x.step()
        try step(&x) {
            try assertVariable($0, "my life", "1 or 2 or 3")
        }
        _ = try x.step()
        _ = try x.step()
        try step(&x) {
            try assertVariable($0, "my house", "acb")
        }
    }

    func testErrors() throws {
        let _: LocationError = try errorTest("put my heart into my soul", (1,4))
        let _: LocationError = try errorTest("it is nothing", (1,0))
        let _: NonNumericExprError = try errorTest("let my life be 5 is greater than \"4\"", (1,32))
        let _: NonNumericExprError = try errorTest("let my life be 5 without \"4\"", (1,24))
        let _: NonNumericExprError = try errorTest("let my life be true without false", (1,15))
        let _: StrayExprError = try errorTest("give it back", (1,0))
        let _: StrayExprError = try errorTest("else", (1,0))
        let _: StrayExprError = try errorTest("take it to the top", (1,0))
        let _: StrayExprError = try errorTest("break it down", (1,0))
        let _: UncallableLocationError = try errorTest("my life is nothing\nmy life taking 1", (2,0))
        let _: NonIndexableLocationError = try errorTest("let my life be 4\nmy life at 5", (2,0))
        let _: LocationError = try errorTest("it at 0 is nothing", (1,0))
        let _: LocationError = try errorTest("put my heart at 5 into my soul", (1,4))
        let _: LocationError = try errorTest("let my heart at 0 be 1", (1,4))
        let _: NonIndexableLocationError = try errorTest("let my life be 4,5\nmy life at 5,5", (2,0))
        let _: InvalidIndexError = try errorTest("let my life be 5\nlet my life at 1 be 0\nmy life at nothing", (3,0))
        let _: NonStringExprError = try errorTest("cut 5 into pieces", (1,4))
        let _: NonStringExprError = try errorTest("let my life be 5\ncut my life into pieces", (2,4))
        let _: NonStringExprError = try errorTest("cut \"my life\" into pieces with 5", (1,31))
        let _: NonArrayExprError = try errorTest("join 5 into pieces", (1,5))
        let _: NonStringExprError = try errorTest("rock my life\nrock my life with 5,6\njoin my life into pieces", (3,5))
        let _: NonStringExprError = try errorTest("rock my life\nrock my life with \"a\",\"b\"\njoin my life with 5", (3,18))
    }
}
