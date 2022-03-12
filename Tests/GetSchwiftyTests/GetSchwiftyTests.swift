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
        let x = try GetSchwifty(input: fizzbuzz, rockout: {o throws in
            let out = try XCTUnwrap(o as? AnyHashable)
            XCTAssertEqual(out, fizzBuzz(n: i))
            XCTAssert(i < 101)
            i += 1
        })

        try! x.run()
    }

    func testIsEven() throws {
        let exp = [
            0: true,
            1: false,
            2: true,
            3: false,
            4: true,
            5: false,
            5.5: false,
            -0.5: false,
            -2: true,
            -4.01: false,
            -4.9: false,
            -6: true]

        let isEven = try! String(contentsOf: URL(fileURLWithPath: "./Tests/iseven.rock"))
        let x = try GetSchwifty(input: isEven)
        for (i, v) in exp {
            try x.run(rockin: { i }, rockout: {o throws in
                let out = try XCTUnwrap(o as? AnyHashable)
                XCTAssertEqual(out, v)
            })
        }
    }

    func testFibonacci() throws {
        let exp = [
            0: 1,
            1: 1,
            2: 2,
            3: 3,
            4: 5,
            5: 8,
            6: 13,
            7: 21]

        let fibonacci = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fibonacci.rock"))
        let x = try GetSchwifty(input: fibonacci)
        for (i, v) in exp {
            try x.run(rockin: { i }, rockout: {o throws in
                let out = try XCTUnwrap(o as? Int)
                XCTAssertEqual(out, v)
            })
        }
    }
}
