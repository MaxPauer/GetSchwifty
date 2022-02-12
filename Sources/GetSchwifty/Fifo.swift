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
