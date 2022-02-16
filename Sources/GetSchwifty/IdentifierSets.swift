infix operator ∪

internal extension Set {
    static func ∪(lhs: Set, rhs: Set) -> Set {
        lhs.union(rhs)
    }
}

internal extension String {
    static var commonVariableIdentifiers: Set<String> {
        Set(["a", "an", "the", "my", "your", "our"])
    }
    static var sayOutputIdentifiers: Set<String> {
        Set(["say", "shout", "whisper", "scream"])
    }
    static var emptyStringIdentifiers: Set<String> {
        Set(["empty", "silent", "silence"])
    }
    static var trueIdentifiers: Set<String> {
        Set(["true", "right", "yes", "ok"])
    }
    static var falseIdentifiers: Set<String> {
        Set(["false", "wrong", "no", "lies"])
    }
    static var nullIdentifiers: Set<String> {
        Set(["null", "nothing", "nobody", "nowhere", "gone"])
    }
    static var sayPoeticStringIdentifiers: Set<String> {
        Set(["say", "says", "said"])
    }
    static var poeticNumberIdentifiers: Set<String> {
        Set(["is", "are", "was", "were"])
    }
    static var letAssignIdentifiers: Set<String> {
        Set(["let"])
    }
    static var putAssignIdentifiers: Set<String> {
        Set(["put"])
    }
    static var listenInputIdentifiers: Set<String> {
        Set(["listen"])
    }
    static var mysteriousIdentifiers: Set<String> {
        Set(["mysterious"])
    }
    static var isContractionIdentifiers: Set<String> {
        Set(["s", "re"])
    }
    static var assignBeIdentifiers: Set<String> {
        Set(["be"])
    }
    static var assignIntoIdentifiers: Set<String> {
        Set(["in", "into"])
    }
    static var toIdentifiers: Set<String> {
        Set(["to"])
    }
    static var pronounIdentifiers: Set<String> {
        Set(["it", "he", "she", "him", "her", "they", "them", "ze", "hir", "zie", "zir", "xe", "xem", "ve", "ver"])
    }
}

internal func ~=(pattern: Set<String>, value: String) -> Bool {
    pattern.contains(value.lowercased())
}
