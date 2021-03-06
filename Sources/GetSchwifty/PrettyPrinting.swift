protocol PrettyNamed: CustomStringConvertible {
    var prettyName: String { get }
}

extension Lex {
    var description: String {
        prettyLiteral != nil ? "‹\(prettyName): \(prettyLiteral!)›" : "‹\(prettyName)›"
    }
}
extension ExprBuilder {
    var description: String { "‹‹\(prettyName)››" }
}
extension ExprP {
    var description: String { "‹‹‹\(prettyName)›››" }
}

extension NewlineLex {
    var prettyName: String { "Newline" }
}
extension DelimiterLex {
    var prettyName: String { "Delimiter" }
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
extension IndexingExprBuilder {
    var prettyName: String { "Indexing: \(target)[\(index)]" }
}
extension CommonVariableNameExprBuilder {
    var prettyName: String { "Variable Name: unfinished=\(first) …" }
}
extension ProperVariableNameExprBuilder {
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
extension LiteralExprBuilder {
    var prettyName: String { "Literal Value: \"\(literal)\"" }
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
extension VoidCallExprBuilder {
    var prettyName: String { "Call: \(op)" }
}
extension BiArithExprBuilder {
    var prettyName: String { "Arithmetic: \(op)" }
}
extension UnArithExprBuilder {
    var prettyName: String { "Arithmetic: \(op)" }
}
extension FunctionCallExprBuilder {
    var prettyName: String { "Function Call" }
}
extension LoopExprBuilder {
    var prettyName: String { "Loop" }
}
extension FunctionDeclExprBuilder {
    var prettyName: String { "Function Declaration" }
}
extension ReturnExprBuilder {
    var prettyName: String { "Return" }
}
extension ElseExprBuilder {
    var prettyName: String { "Else" }
}
extension BreakExprBuilder {
    var prettyName: String { "Break" }
}
extension ContinueExprBuilder {
    var prettyName: String { "Continue" }
}
extension ConditionalExprBuilder {
    var prettyName: String { "Conditional" }
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
extension LiteralExpr {
    var prettyName: String { "Literal Value: \(literal)" }
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
extension ElseExpr {
    var prettyName: String { "Else" }
}
extension BreakExpr {
    var prettyName: String { "Break" }
}
extension ContinueExpr {
    var prettyName: String { "Continue" }
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
