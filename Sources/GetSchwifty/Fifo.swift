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

internal struct Fifo<T: IteratorProtocol> {
    private var iter: T
    private var ll: DLinkedList<T.Element>

    init(_ t: T) {
        iter = t
        ll = DLinkedList()
        ll.pushBack(iter.next())
    }

    mutating func pop() -> T.Element? {
        ll.pushBack(iter.next())
        return ll.popFront()
    }

    mutating func drop() {
        _ = ll.popFront()
    }

    func peek() -> T.Element? {
        ll.peekFront()
    }
}
