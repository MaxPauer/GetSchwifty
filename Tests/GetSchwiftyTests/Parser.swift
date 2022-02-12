import XCTest
@testable import GetSchwifty

final class ParserTests: XCTestCase {
    func testCommonVariable() throws {
        let testParse = { (inp: String, exp: String) in
            let p = try! Parser(lexemes: lex(inp))
            XCTAssertEqual(p.exprs.count, 1)
            XCTAssertEqual((p.exprs[0] as! CommonVariableName).name, exp)
        }

        testParse("A horse", "a horse")
        testParse("An  elf", "an elf")
        testParse("THE HOUSE", "the house")
        testParse("My\tlife", "my life")
        testParse("your Heart", "your heart")
        testParse("our SoCiEtY", "our society")
    }

    func testFizzBuzz() throws {
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))
        let lexemes = lex(fizzbuzz)
        let parser = try! Parser(lexemes: lexemes)
        XCTAssertEqual(parser.lines, 26)
    }
}
