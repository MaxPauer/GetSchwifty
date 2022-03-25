class DLinkedList<T> {
    private class LLNode<T> {
        let value: T
        var previous: LLNode?
        var next: LLNode?

        init(_ v: T) {
            value = v
        }
    }

    private struct ConsumingSequencer<T>: IteratorProtocol, Sequence {
        private var _next: () -> T?
        func next() -> T? { _next() }
        init(_ next: @escaping () -> T?) { _next = next }
    }
    private struct NonConsumingSequencer<T>: IteratorProtocol, Sequence {
        private var _next: (LLNode<T>) -> LLNode<T>?
        private var current: LLNode<T>?
        mutating func next() -> T? {
            guard let c = current else { return nil }
            current = _next(c)
            return c.value
        }
        init(start: LLNode<T>?, _ next: @escaping (LLNode<T>) -> LLNode<T>?) {
            current = start
            _next = next
        }
    }

    private var front: LLNode<T>?
    private var back: LLNode<T>?

    var isEmpty: Bool {
        assert((front == nil) == (back == nil))
        return front == nil
    }

    func pushFront(_ v: T?) {
        guard let v = v else { return }
        let node = LLNode(v)
        if isEmpty {
            front = node
            back = node
        } else {
            front!.previous = node
            node.next = front
            front = node
        }
    }

    func pushBack(_ v: T?) {
        guard let v = v else { return }
        let node = LLNode(v)
        if isEmpty {
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

    func popFront() -> T? {
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

    func popBack() -> T? {
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

    var consumeFrontToBack: AnySequence<T> {
        AnySequence(ConsumingSequencer { self.popFront() })
    }

    var walkFrontToBack: AnySequence<T> {
        AnySequence(NonConsumingSequencer(start: self.front) {
            $0.next
        })
    }
}

struct Fifo<T: IteratorProtocol> {
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

struct RockstarArray {
    internal var dict = [AnyHashable: Any]()
    private var insertionOrder = DLinkedList<AnyHashable>()
    private var nextIndex: Int = 0

    var length: Int { nextIndex }
    var count: Int { dict.count }

    mutating func values() -> [Any] {
        return insertionOrder.walkFrontToBack.map {
            return dict[$0]!
        }
    }

    mutating func pop() -> Any {
        guard let i = insertionOrder.popFront() else {
            return Rockstar.null
        }
        defer { dict.removeValue(forKey: i) }
        return dict[i]!
    }

    mutating func push(_ value: Any) {
        set(int: nextIndex, value)
    }

    mutating private func set(int i: Int, _ newValue: Any) {
        set(any: i, newValue)
        if i >= nextIndex {
            nextIndex = i+1
        }
    }

    mutating private func set(any i: AnyHashable, _ newValue: Any) {
        let hadKey = dict[i] != nil
        dict[i] = newValue
        if !hadKey {
            insertionOrder.pushBack(i)
        }
    }

    subscript(i: AnyHashable) -> Any {
        get { dict[i] ?? Rockstar.mysterious }
        set {
            switch i {
            case let d as Double:
                if let ii = Int(exactly: d) {
                    set(int: ii, newValue)
                }
            default:
                set(any: i, newValue)
            }
        }
    }

    init(_ arr: [Any]) {
        arr.forEach { self.push($0) }
    }

    init(_ dict: [AnyHashable: Any]) {
        dict.forEach {key, value in
            self[key] = value
        }
    }

    init() {}
}
