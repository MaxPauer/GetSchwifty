import XCTest
@testable import GetSchwifty

final class EvalTests: XCTestCase {
    func testBoolAssignment() throws {
        var c = MainEvalContext(input: "put true into my world\nlet my house be false\nput my world into my house")
        try! _ = c.step()
        XCTAssertEqual(c.variables["my world"] as! Bool, true)
        try! _ = c.step()
        XCTAssertEqual(c.variables["my world"] as! Bool, true)
        XCTAssertEqual(c.variables["my house"] as! Bool, false)
        try! _ = c.step()
        XCTAssertEqual(c.variables["my world"] as! Bool, true)
        XCTAssertEqual(c.variables["my house"] as! Bool, true)
        XCTAssertTrue(try! c.step())
        XCTAssertFalse(try! c.step())
    }
}
