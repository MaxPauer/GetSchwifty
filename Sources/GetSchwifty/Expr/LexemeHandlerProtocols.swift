internal protocol IgnoresWhitespaceLexP: ExprBuilder {}
internal protocol IgnoresCommentLexP: ExprBuilder {}
internal protocol ThrowsIdentifierLexP: ExprBuilder {}
internal protocol ThrowsStringLexP: ExprBuilder {}
internal protocol ThrowsNumberLexP: ExprBuilder {}
internal protocol ThrowsDelimiterLexP: ExprBuilder {}

internal extension IgnoresWhitespaceLexP {
    func handleWhitespaceLex(_ w: WhitespaceLex) throws -> ExprBuilder {
        return self
    }
}

internal extension IgnoresCommentLexP {
    func handleCommentLex(_ c: CommentLex) throws -> ExprBuilder {
        return self
    }
}

internal extension ThrowsIdentifierLexP {
    func handleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: i, parsing: self)
    }
}

internal extension ThrowsStringLexP {
    func handleStringLex(_ s: StringLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: s, parsing: self)
    }
}

internal extension ThrowsNumberLexP {
    func handleNumberLex(_ n: NumberLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: n, parsing: self)
    }
}

internal extension ThrowsDelimiterLexP {
    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: d, parsing: self)
    }
}

internal protocol CanPushLexThroughP: ExprBuilder {
    func pushThrough(_ lex: Lex) throws -> ExprBuilder
}
internal protocol PushesIdentifierLexThroughP: CanPushLexThroughP {}
internal protocol PushesStringLexThroughP: CanPushLexThroughP {}
internal protocol PushesNumberLexThroughP: CanPushLexThroughP {}
internal protocol PushesDelimiterLexThroughP: CanPushLexThroughP {}

internal extension PushesIdentifierLexThroughP {
    func handleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder {
        return try pushThrough(i)
    }
}

internal extension PushesStringLexThroughP {
    func handleStringLex(_ s: StringLex) throws -> ExprBuilder {
        return try pushThrough(s)
    }
}

internal extension PushesNumberLexThroughP {
    func handleNumberLex(_ n: NumberLex) throws -> ExprBuilder {
        return try pushThrough(n)
    }
}

internal extension PushesDelimiterLexThroughP {
    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        return try pushThrough(d)
    }
}

internal protocol DelimiterLexToListP: ArithExprBuilder {}

extension DelimiterLexToListP {
    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        return ListExprBuilder(first: self, isStatement: isStatement, takesAnd: d.isComma)
    }
}
