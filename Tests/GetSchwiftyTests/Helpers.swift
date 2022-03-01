import XCTest
@testable import GetSchwifty

final class DLinkedListTests: XCTestCase {
    func test1() throws {
        let ll = DLinkedList<Int>()

        ll.pushBack(1)
        XCTAssertEqual(ll.popFront(), 1)
        XCTAssertNil(ll.popFront())
        XCTAssertNil(ll.popBack())

        ll.pushBack(1)
        XCTAssertEqual(ll.popBack(), 1)
        XCTAssertNil(ll.popFront())
        XCTAssertNil(ll.popBack())

        ll.pushBack(1)
        XCTAssertEqual(ll.popBack(), 1)
        XCTAssertNil(ll.popBack())
        XCTAssertNil(ll.popFront())
    }

    func test2() throws {
        let ll = DLinkedList<Int>()

        ll.pushBack(1)
        ll.pushBack(2)
        XCTAssertEqual(ll.popFront(), 1)
        XCTAssertEqual(ll.popFront(), 2)
        XCTAssertNil(ll.popFront())
        XCTAssertNil(ll.popBack())

        ll.pushBack(1)
        ll.pushBack(2)
        XCTAssertEqual(ll.popBack(), 2)
        XCTAssertEqual(ll.popBack(), 1)
        XCTAssertNil(ll.popFront())
        XCTAssertNil(ll.popBack())

        ll.pushBack(1)
        ll.pushBack(2)
        XCTAssertEqual(ll.popBack(), 2)
        XCTAssertEqual(ll.popFront(), 1)
        XCTAssertNil(ll.popFront())
        XCTAssertNil(ll.popBack())
    }

    func test3() throws {
        let ll = DLinkedList<Int>()

        ll.pushBack(1)
        ll.pushBack(2)
        ll.pushBack(3)
        XCTAssertEqual(ll.popFront(), 1)
        XCTAssertEqual(ll.popBack(), 3)
        XCTAssertEqual(ll.popBack(), 2)
        XCTAssertNil(ll.popFront())
        XCTAssertNil(ll.popBack())
    }

    func test11() throws {
        let ll = DLinkedList<Int>()

        ll.pushFront(1)
        XCTAssertEqual(ll.popFront(), 1)
        XCTAssertNil(ll.popFront())
        XCTAssertNil(ll.popBack())

        ll.pushFront(1)
        XCTAssertEqual(ll.popBack(), 1)
        XCTAssertNil(ll.popFront())
        XCTAssertNil(ll.popBack())

        ll.pushFront(1)
        XCTAssertEqual(ll.popBack(), 1)
        XCTAssertNil(ll.popBack())
        XCTAssertNil(ll.popFront())
    }

    func test12() throws {
        let ll = DLinkedList<Int>()

        ll.pushFront(1)
        ll.pushFront(2)
        XCTAssertEqual(ll.popFront(), 2)
        XCTAssertEqual(ll.popFront(), 1)
        XCTAssertNil(ll.popFront())
        XCTAssertNil(ll.popBack())

        ll.pushFront(1)
        ll.pushFront(2)
        XCTAssertEqual(ll.popBack(), 1)
        XCTAssertEqual(ll.popBack(), 2)
        XCTAssertNil(ll.popFront())
        XCTAssertNil(ll.popBack())

        ll.pushFront(1)
        ll.pushFront(2)
        XCTAssertEqual(ll.popBack(), 1)
        XCTAssertEqual(ll.popFront(), 2)
        XCTAssertNil(ll.popFront())
        XCTAssertNil(ll.popBack())
    }

    func test13() throws {
        let ll = DLinkedList<Int>()

        ll.pushFront(1)
        ll.pushFront(2)
        ll.pushFront(3)
        XCTAssertEqual(ll.popFront(), 3)
        XCTAssertEqual(ll.popBack(), 1)
        XCTAssertEqual(ll.popBack(), 2)
        XCTAssertNil(ll.popFront())
        XCTAssertNil(ll.popBack())
    }
}
