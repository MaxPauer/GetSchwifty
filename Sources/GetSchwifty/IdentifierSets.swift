infix operator ∪: AdditionPrecedence

internal extension Set {
    static func ∪(lhs: Set, rhs: Set) -> Set {
        lhs.union(rhs)
    }
}

internal func ~=(pattern: Set<String>, value: String) -> Bool {
    pattern.contains(value.lowercased())
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
    static var isIdentifiers: Set<String> {
        Set(["is", "are", "was", "were"]) ∪ String.isContractionIdentifiers
    }
    static var isContractionIdentifiers: Set<String> {
        Set(["'s", "'re"])
    }
    static var isntIdentifiers: Set<String> {
        Set(["isnt", "arent", "wasnt", "werent", "aint"])
    }
    static var assignIntoIdentifiers: Set<String> {
        Set(["in", "into"])
    }
    static var pronounIdentifiers: Set<String> {
        Set(["it", "he", "she", "him", "her", "they", "them", "ze", "hir", "zie", "zir", "xe", "xem", "ve", "ver"])
    }
    static var pushIdentifiers: Set<String> {
        Set(["rock", "push"])
    }
    static var popIdentifiers: Set<String> {
        Set(["roll", "pop"])
    }
    static var additionIdentifiers: Set<String> {
        Set(["plus", "with"])
    }
    static var subtractionIdentifiers: Set<String> {
        Set(["minus", "without"])
    }
    static var multiplicationIdentifiers: Set<String> {
        Set(["times", "of"])
    }
    static var divisionIdentifiers: Set<String> {
        Set(["over", "between"])
    }
    static var highIdentifiers: Set<String> {
        Set(["high", "great", "big", "strong"])
    }
    static var higherIdentifiers: Set<String> {
        Set(["higher", "greater", "bigger", "stronger"])
    }
    static var lowIdentifiers: Set<String> {
        Set(["low", "little", "small", "weak"])
    }
    static var lowerIdentifiers: Set<String> {
        Set(["lower", "less", "smaller", "weaker"])
    }
    static var roundIdentifiers: Set<String> {
        Set(["round", "around"])
    }
    static var castIdentifiers: Set<String> {
        Set(["cast", "burn"])
    }
    static var splitIdentifiers: Set<String> {
        Set(["split", "shatter", "cut"])
    }
    static var joinIdentifiers: Set<String> {
        Set(["join", "unite"])
    }
    static var takesIdentifiers: Set<String> {
        Set(["takes", "wants"])
    }
    static var returnIdentifiers: Set<String> {
        Set(["return", "send"]) ∪ String.giveIdentifiers
    }

    static var letAssignIdentifiers: Set<String> { Set(["let"]) }
    static var putAssignIdentifiers: Set<String> { Set(["put"]) }
    static var listenInputIdentifiers: Set<String> { Set(["listen"]) }
    static var mysteriousIdentifiers: Set<String> { Set(["mysterious"]) }
    static var assignBeIdentifiers: Set<String> { Set(["be"]) }
    static var toIdentifiers: Set<String> { Set(["to"]) }
    static var indexingIdentifiers: Set<String> { Set(["at"]) }
    static var buildIdentifiers: Set<String> { Set(["build"]) }
    static var upIdentifiers: Set<String> { Set(["up"]) }
    static var knockIdentifiers: Set<String> { Set(["knock"]) }
    static var downIdentifiers: Set<String> { Set(["down"]) }
    static var withIdentifiers: Set<String> { Set(["with"]) }
    static var andIdentifiers: Set<String> { Set(["and"]) }
    static var orIdentifiers: Set<String> { Set(["or"]) }
    static var norIdentifiers: Set<String> { Set(["nor"]) }
    static var notIdentifiers: Set<String> { Set(["not"]) }
    static var asIdentifiers: Set<String> { Set(["as"]) }
    static var thanIdentifiers: Set<String> { Set(["than"]) }
    static var likeIdentifiers: Set<String> { Set(["like"]) }
    static var turnIdentifiers: Set<String> { Set(["turn"]) }
    static var intoIdentifiers: Set<String> { Set(["into"]) }
    static var takingIdentifiers: Set<String> { Set(["taking"]) }
    static var whileIdentifiers: Set<String> { Set(["while"]) }
    static var untilIdentifiers: Set<String> { Set(["until"]) }
    static var giveIdentifiers: Set<String> { Set(["give"]) }
    static var backIdentifiers: Set<String> { Set(["back"]) }
    static var elseIdentifiers: Set<String> { Set(["else"]) }

    static var constantIdentifiers: Set<String> {
        String.emptyStringIdentifiers
        ∪ String.trueIdentifiers
        ∪ String.falseIdentifiers
        ∪ String.mysteriousIdentifiers
        ∪ String.nullIdentifiers
    }
}
