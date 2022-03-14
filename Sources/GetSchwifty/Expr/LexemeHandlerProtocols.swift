protocol IgnoresWhitespaceLexP: ExprBuilder {}
protocol IgnoresCommentLexP: ExprBuilder {}
protocol ThrowsIdentifierLexP: ExprBuilder {}
protocol ThrowsStringLexP: ExprBuilder {}
protocol ThrowsNumberLexP: ExprBuilder {}
protocol ThrowsDelimiterLexP: ExprBuilder {}

extension IgnoresWhitespaceLexP {
    func handleWhitespaceLex(_ w: WhitespaceLex) throws -> ExprBuilder {
        return self
    }
}

extension IgnoresCommentLexP {
    func handleCommentLex(_ c: CommentLex) throws -> ExprBuilder {
        return self
    }
}

extension ThrowsIdentifierLexP {
    func handleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: i, parsing: self)
    }
}

extension ThrowsStringLexP {
    func handleStringLex(_ s: StringLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: s, parsing: self)
    }
}

extension ThrowsNumberLexP {
    func handleNumberLex(_ n: NumberLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: n, parsing: self)
    }
}

extension ThrowsDelimiterLexP {
    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        throw UnexpectedLexemeError(got: d, parsing: self)
    }
}

protocol CanPushLexThroughP: ExprBuilder {
    func pushThrough(_ lex: Lex) throws -> ExprBuilder
}
protocol PushesIdentifierLexThroughP: CanPushLexThroughP {}
protocol PushesStringLexThroughP: CanPushLexThroughP {}
protocol PushesNumberLexThroughP: CanPushLexThroughP {}
protocol PushesDelimiterLexThroughP: CanPushLexThroughP {}

extension PushesIdentifierLexThroughP {
    func handleIdentifierLex(_ i: IdentifierLex) throws -> ExprBuilder {
        return try pushThrough(i)
    }
}

extension PushesStringLexThroughP {
    func handleStringLex(_ s: StringLex) throws -> ExprBuilder {
        return try pushThrough(s)
    }
}

extension PushesNumberLexThroughP {
    func handleNumberLex(_ n: NumberLex) throws -> ExprBuilder {
        return try pushThrough(n)
    }
}

extension PushesDelimiterLexThroughP {
    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        return try pushThrough(d)
    }
}

protocol DelimiterLexToListP: ArithExprBuilder {}

extension DelimiterLexToListP {
    func handleDelimiterLex(_ d: DelimiterLex) throws -> ExprBuilder {
        return ListExprBuilder(first: self, isStatement: isStatement, takesAnd: d.isComma)
    }
}
