import XCTest
@testable import GetSchwifty

final class GetSchwiftyTests: XCTestCase {
    func testFizzBuzz() throws {
        func fizzBuzz(n: Int) -> AnyHashable {
            let isDiv3 = n % 3 == 0
            let isDiv5 = n % 5 == 0
            if isDiv3 && isDiv5 {
                return "FizzBuzz!"
            }
            if isDiv3 {
                return "Fizz!"
            }
            if isDiv5 {
                return "Buzz!"
            }
            return n
        }

        var i = 1
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))
        let x = MainEvalContext(input: fizzbuzz, stdout: {o throws in
            let out = try XCTUnwrap(o as? AnyHashable)
            XCTAssertEqual(out, fizzBuzz(n: i))
            XCTAssert(i < 101)
            i += 1
        })

        try! x.run()
    }
}
