internal extension String {
    var firstCharIsUpperCase: Bool {
        return self.first?.isUppercase ?? false
    }
}

internal protocol FinalizedLocationExprBuilder: DelimiterToListArithValueExprBuilder {}

extension FinalizedLocationExprBuilder {
    var canTerminate: Bool { true }

    func postHandleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        let word = id.literal
        switch word {
        case String.sayPoeticStringIdentifiers:
            return PoeticStringAssignmentExprBuilder(target: self)
        case String.indexingIdentifiers:
            return IndexingLocationExprBuilder(target: self, isStatement: isStatement)
        case String.takingIdentifiers:
            return FunctionCallExprBuilder(head: self)
        case String.takesIdentifiers:
            return FunctionDeclExprBuilder(head: self)
        default:
            throw UnexpectedIdentifierError(got: id, parsing: self, expecting:
                String.isIdentifiers ∪ String.sayPoeticStringIdentifiers ∪ String.indexingIdentifiers ∪ String.takingIdentifiers)
        }
    }
}

internal class PronounExprBuilder: FinalizedLocationExprBuilder {
    let isStatement: Bool
    var range: LexRange!

    init(isStatement iss: Bool) {
        isStatement = iss
    }

    func build() -> ExprP {
        return PronounExpr(range: range)
    }
}

internal class IndexingLocationExprBuilder:
        DelimiterToListArithValueExprBuilder, PushesStringThrough, PushesNumberThrough {
    let target: ExprBuilder
    lazy var index: ExprBuilder = VanillaExprBuilder(parent: self)
    let isStatement: Bool
    var range: LexRange!

    init(target t: ExprBuilder, isStatement iss: Bool) {
        target = t
        isStatement = iss
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        index = try index.partialPush(lex)
        return self
    }

    func postHandleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder {
        return try pushThrough(i)
    }

    func build() throws -> ExprP {
        let t: IndexableExprP = try target.build(asChildOf: self)
        let i: ValueExprP = try index.build(asChildOf: self)
        return IndexingExpr(source: t, operand: i, range: range)
    }
}

internal class VariableNameExprBuilder: FinalizedLocationExprBuilder {
    let name: String
    let isStatement: Bool
    var range: LexRange!

    init(name n: String, isStatement iss: Bool) {
        name = n.lowercased()
        isStatement = iss
    }

    func build() -> ExprP {
        return VariableNameExpr(name: name, range: range)
    }
}

internal class CommonVariableNameExprBuilder: ExprBuilder {
    let first: String
    var range: LexRange!
    let isStatement: Bool

    init(first f: String, isStatement iss: Bool) {
        first = f
        isStatement = iss
    }

    func push(_ lex: Lex) throws -> PartialExpr {
        if lex is NewlineLex {
            throw UnexpectedLexemeError(got: lex, parsing: self)
        }
        return .builder(try partialPush(lex))
    }

    func build() throws -> ExprP {
        assertionFailure("must not be called")
        return NopExpr(range: range)
    }

    func handleIdentifierLex(_ id: IdentifierLex) -> ExprBuilder {
        let word = id.literal
        return self |=> VariableNameExprBuilder(name: "\(first) \(word)", isStatement: isStatement)
    }
}

internal class ProperVariableNameExprBuilder: SingleExprBuilder, PushesDelimiterThrough {
    private(set) var words: [String]
    var range: LexRange!
    let isStatement: Bool
    var name: String { words.joined(separator: " ") }

    init(first: String, isStatement iss: Bool) {
        words = [first]
        isStatement = iss
    }

    func build() throws -> ExprP {
        return finalize().build()
    }

    func finalize() -> VariableNameExprBuilder {
        self |=> VariableNameExprBuilder(name: name, isStatement: isStatement)
    }

    func pushThrough(_ lex: Lex) throws -> ExprBuilder {
        let newMe = finalize()
        return try newMe.partialPush(lex)
    }

    func handleIdentifierLex(_ id: IdentifierLex) throws -> ExprBuilder {
        let word = id.literal
        if word.firstCharIsUpperCase {
            words.append(word)
            return self
        } else {
            return try pushThrough(id)
        }
    }
}
