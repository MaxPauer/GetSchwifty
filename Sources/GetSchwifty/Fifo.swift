internal struct DLinkedList<T> {
    private class LLNode<T> {
        let value: T
        var previous: LLNode?
        var next: LLNode?

        init(_ v: T) {
            value = v
        }
    }

    private var front: LLNode<T>?
    private var back: LLNode<T>?

    mutating func pushFront(_ v: T?) {
        guard let v = v else { return }
        let node = LLNode(v)
        if front == nil {
            front = node
            back = node
        } else {
            front!.previous = node
            node.next = front
            front = node
        }
    }

    mutating func pushBack(_ v: T?) {
        guard let v = v else { return }
        let node = LLNode(v)
        if back == nil {
            back = node
            front = node
        } else {
            back!.next = node
            node.previous = back
            back = node
        }
    }

    func peekFront() -> T? { front?.value }
    func peekBack() -> T? { back?.value }

    mutating func popFront() -> T? {
        guard let oldFront = front else { return nil }
        if oldFront.next == nil {
            front = nil
            back = nil
        } else {
            oldFront.next!.previous = nil
            front = oldFront.next!
        }
        return oldFront.value
    }

    mutating func popBack() -> T? {
        guard let oldBack = back else { return nil }
        if oldBack.previous == nil {
            front = nil
            back = nil
        } else {
            oldBack.previous!.next = nil
            back = oldBack.previous!
        }
        return oldBack.value
    }
}

internal protocol Fifoable: BidirectionalCollection {
    associatedtype Element
    init(_: ReversedCollection<Self>)
    func reversed() -> ReversedCollection<Self>
    mutating func popLast() -> Element?
    var last: Element? { get }
}

extension String: Fifoable {}
extension Array: Fifoable {}

internal struct Fifo<T: Fifoable> {
    private var intern: T
    init(_ t: T) {
        intern = T(t.reversed())
    }
    mutating func pop() -> T.Element? {
        intern.popLast()
    }
    mutating func drop() {
        _ = pop()
    }
    func peek() -> T.Element? {
        intern.last
    }
}
