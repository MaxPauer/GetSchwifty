protocol PrettyNamed: CustomStringConvertible {
    var prettyName: String { get }
}

extension Lex {
    var description: String {
        prettyLiteral != nil ? "‹\(prettyName): \(prettyLiteral!)›" : "‹\(prettyName)›"
    }
}
extension ExprBuilder {
    var description: String {
        "‹‹\(prettyName)››"
    }
}
extension ExprP {
    var description: String {
        "‹‹‹\(prettyName)›››"
    }
}

extension NewlineLex {
    var prettyName: String { "Newline" }
}
extension DelimiterLex {
    var prettyName: String {"Delimiter" }
}
extension ContractionLex {
    var prettyName: String { "Contraction" }
}
extension WhitespaceLex {
    var prettyName: String { "\"Whitespace\"" }
}
extension CommentLex {
    var prettyName: String { "Comment" }
}
extension StringLex {
    var prettyName: String { "String" }
}
extension IdentifierLex {
    var prettyName: String { "Identifier" }
}
extension NumberLex {
    var prettyName: String { "Number" }
}

extension VanillaExprBuilder {
    var prettyName: String { "Vanilla" }
}
extension PronounExprBuilder {
    var prettyName: String { "Pronoun" }
}
extension VariableNameExprBuilder {
    var prettyName: String { "Variable Name: \(name)" }
}
extension IndexingLocationExprBuilder {
    var prettyName: String { "Indexing: \(target)[\(index)]" }
}
extension CommonVariableNameExprBuilder {
    var prettyName: String { "Variable Name: unfinished=\(first) …" }
}
extension ProperVariableNameExprBuilder{
    var prettyName: String { "Variable Name: unfinished=\(name) …" }
}
extension PoeticConstantExprBuilder {
    var prettyName: String { "Poetic Constant" }
}
extension PoeticNumberExprBuilder {
    var prettyName: String { "Poetic Number" }
}
extension PoeticNumberishAssignmentExprBuilder {
    var prettyName: String { "Poetic Number/Constant Assignment" }
}
extension PoeticStringAssignmentExprBuilder {
    var prettyName: String { "Poetic String Assignment" }
}
extension AssignmentExprBuilder {
    var prettyName: String { "Assignment" }
}
extension CrementExprBuilder {
    var prettyName: String { "In-/Decrement" }
}
extension InputExprBuilder {
    var prettyName: String { "Input" }
}
extension OutputExprBuilder {
    var prettyName: String { "Output" }
}
extension ListExprBuilder {
    var prettyName: String { "List" }
}
extension StringExprBuilder {
    var prettyName: String { "String Value: \"\(literal)\"" }
}
extension NumberExprBuilder {
    var prettyName: String { "Numeric Value: \"\(literal)\"" }
}
extension BoolExprBuilder {
    var prettyName: String { "Boolean Value: \"\(literal)\"" }
}
extension NullExprBuilder {
    var prettyName: String { "Null Value" }
}
extension MysteriousExprBuilder {
    var prettyName: String { "Mysterious Value" }
}
extension PushExprBuilder {
    var prettyName: String { "Rock/Push" }
}
extension PopExprBuilder {
    var prettyName: String { "Roll/Pop" }
}
extension RoundExprBuilder {
    var prettyName: String { "Rounding" }
}
extension ArithExprBuilder {
    var prettyName: String { "Arithmetic: \(op)" }
}

extension NopExpr {
    var prettyName: String { "Nop" }
}
extension PronounExpr {
    var prettyName: String { "Pronoun" }
}
extension VariableNameExpr {
    var prettyName: String { "Variable Name: \(name)" }
}
extension BoolExpr {
    var prettyName: String { "Boolean Value: \(literal)" }
}
extension NumberExpr {
    var prettyName: String { "Numeric Value: \"\(literal)\"" }
}
extension StringExpr {
    var prettyName: String { "String Value: \"\(literal)\"" }
}
extension NullExpr {
    var prettyName: String { "Null Value" }
}
extension MysteriousExpr {
    var prettyName: String { "Mysterious Value" }
}
extension IndexingExpr {
    var prettyName: String { "Indexing" }
}
extension ListExpr {
    var prettyName: String { "List" }
}
extension ConditionalExpr {
    var prettyName: String { "Conditional" }
}
extension LoopExpr {
    var prettyName: String { "Loop" }
}
extension ReturnExpr {
    var prettyName: String { "Return" }
}
extension FunctionDeclExpr {
    var prettyName: String { "Function Declaration" }
}
extension FunctionCallExpr {
    var prettyName: String { "Function Call: \(head)" }
}
extension VoidCallExpr {
    var prettyName: String { "Void Function Call: \(head)" }
}
