import XCTest
@testable import GetSchwifty

final class ParserTests: XCTestCase {
    func testFizzBuzz() throws {
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))
        let lexemes = lex(fizzbuzz)
        let parser = Parser(lexemes: lexemes)
        XCTAssertEqual(parser.lines, 26)
    }
}
