import XCTest
@testable import GetSchwifty

final class ParserTests: XCTestCase {
    func parse(_ inp: String) throws -> Parser {
        return Parser(input: inp)
    }

    func testVariableNames() throws {
        func testParse(_ inp: String, _ exp: String) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let v = try XCTUnwrap(try p.next() as? VariableNameExpr)
            XCTAssertEqual(v.name, exp)
            XCTAssert(try p.next() is NopExpr)
        }

        try testParse("A horse", "a horse")
        try testParse("An  elf", "an elf")
        try testParse("THE HOUSE", "the house")
        try testParse("My\tlife", "my life")
        try testParse("your Heart", "your heart")
        try testParse("our SoCiEtY", "our society")
        try testParse("Doctor Feelgood", "doctor feelgood")
        try testParse("Distance In Km", "distance in km")
        try testParse("Doctor", "doctor")
        try testParse("she'lob", "shelob")
    }

    func testPronouns() throws {
        for inp in ["it", "he", "she", "him", "her", "they", "them", "th'em", "ze", "hir", "zie", "zir", "xe", "xem", "ve", "ver"] {
            var p = try XCTUnwrap(self.parse(inp))
            _ = try XCTUnwrap(try p.next() as? PronounExpr)
        }
    }

    func assignParseTest<U, V>(_ inp: String, _ expVarName: String, _ expValue: U) throws -> V where U: Equatable, V: LiteralExprP, V.LiteralT == U {
        var p = try XCTUnwrap(self.parse(inp))
        let ass = try XCTUnwrap(p.next() as? VoidCallExpr)
        XCTAssertEqual(ass.head, .assign)
        XCTAssert(try p.next() is NopExpr)
        XCTAssertEqual((ass.target as! VariableNameExpr).name, expVarName)
        let rhs = try XCTUnwrap(ass.source as? V)
        XCTAssertEqual(rhs.literal, expValue)
        return rhs
    }

    func testPoeticNumberLiteral() throws {
        let _: NumberExpr = try assignParseTest("heaven is a halfpipe", "heaven", 18)
        let _: NumberExpr = try assignParseTest("My life's fucked", "my life", 6)
        let _: NumberExpr = try assignParseTest("Your lies're my death", "your lies", 25)
        let _: NumberExpr = try assignParseTest("Your lies're my death's death", "your lies", 265)
        let _: NumberExpr = try assignParseTest("My life's fucked''", "my life", 6)
        let _: NumberExpr = try assignParseTest("My life's fucked'd", "my life", 7)
        let _: NumberExpr = try assignParseTest("My life's  fucked'd", "my life", 7)
        let _: NumberExpr = try assignParseTest("My life's fucked'd ", "my life", 7)
        let _: NumberExpr = try assignParseTest("My life's fucked''d", "my life", 7)
        let _: NumberExpr = try assignParseTest("My life's fucked'd'd", "my life", 8)
        let _: NumberExpr = try assignParseTest("heaven is a halfhalfpipe", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a halfhalfpipe''", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a ha'lfhalfpipe", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a ha''lfhalfpipe", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a half'halfpipe", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a halfhalfpi'pe", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a half'halfpi'pe", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a h'a'l'f'h'a'l'f'p'i'p'e", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a h'a'l'f'h'a'l'f'p'i'p'e'", "heaven", 12)
        let _: NumberExpr = try assignParseTest("heaven is a half.pipe", "heaven", 14.4)
        let _: NumberExpr = try assignParseTest("heaven is a half.pipe pipe pi", "heaven", 14.442)
        let _: NumberExpr = try assignParseTest("heaven is a half.pipe pipe pi. pip", "heaven", 14.4423)
    }

    func testPoeticConstantLiteral() throws {
        let _: NullExpr = try assignParseTest("My life's gone", "my life", Rockstar.null)
        let _: BoolExpr = try assignParseTest("My life's lies lol", "my life", false)
        let _: MysteriousExpr = try assignParseTest("My life's mysterious", "my life", Rockstar.mysterious)
    }

    func testPoeticStringLiteral() throws {
        let _: StringExpr = try assignParseTest("(when i was 17) my father said to me A wealthy man had the things I wanted", "my father", "to me A wealthy man had the things I wanted")
        let _: StringExpr = try assignParseTest("(when i was 17) my father said to me A wealthy man had the thing's I wanted", "my father", "to me A wealthy man had the thing's I wanted")
        let _: StringExpr = try assignParseTest("(when i was 17) my father said to me A wealthy man had the things I wan'ed", "my father", "to me A wealthy man had the things I wan'ed")
        let _: StringExpr = try assignParseTest("(when i was 17) my father said to me A wealthy man had the things I waned'", "my father", "to me A wealthy man had the things I waned'")
        let _: StringExpr = try assignParseTest("Mother says good \"night\" good(fright)\t good124.5e2", "mother", "good \"night\" good(fright)\t good124.5e2")
        let _: StringExpr = try assignParseTest("Father say  \\ lala 'sick hui'  ", "father", " \\ lala 'sick hui'  ")
        let _: StringExpr = try assignParseTest("brother say ", "brother", "")
        let _: StringExpr = try assignParseTest("my father said", "my father", "")
    }

    func testLetAssignment() throws {
        let _: StringExpr = try assignParseTest("let my life be \"GREAT\"", "my life", "GREAT")
        let _: NumberExpr = try assignParseTest("let my life be 42.0", "my life", 42.0)
        let _: BoolExpr = try assignParseTest("let The Devil be right", "the devil", true)
        let _: BoolExpr = try assignParseTest("let The Devil be wrong", "the devil", false)
        let _: NullExpr = try assignParseTest("let hate be nothing", "hate", Rockstar.null)
        let _: MysteriousExpr = try assignParseTest("let dragons be mysterious", "dragons", Rockstar.mysterious)
    }

    func testPutAssignment() throws {
        let _: NumberExpr = try assignParseTest("put 42 in my life", "my life", 42.0)
        let _: StringExpr = try assignParseTest("put \"squirrels\" into my pants", "my pants", "squirrels")
        let _: StringExpr = try assignParseTest("put silence into my pants", "my pants", "")
    }

    func testLetWithAssignment() throws {
        func parseTest(_ inp: String, _ op: FunctionCallExpr.Op, _ val: Double) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let ass = try XCTUnwrap(p.next() as? VoidCallExpr)
            XCTAssertEqual(ass.head, .assign)
            XCTAssert(try p.next() is NopExpr)
            let lhsTar = try XCTUnwrap(ass.target as? VariableNameExpr)
            let rhs = try XCTUnwrap(ass.source as? FunctionCallExpr)
            XCTAssertEqual(rhs.head, op)
            let rhsTar = try XCTUnwrap(rhs.args[0] as? VariableNameExpr)
            let rhsVal = try XCTUnwrap(rhs.args[1] as? NumberExpr)
            XCTAssertEqual(lhsTar.name, rhsTar.name)
            XCTAssertEqual(rhsVal.literal, val)
        }
        try parseTest("let the devil be plus 5", .add, 5)
        try parseTest("let the devil be minus 6", .sub, 6)
        try parseTest("let the devil be of 7", .mul, 7)
        try parseTest("let the devil be between 8", .div, 8)
    }

    func testInput() throws {
        let testParse = { (inp: String, expLocName: String?) in
            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(try p.next() as? VoidCallExpr)
            XCTAssertEqual(i.head, .scan)
            XCTAssert(try p.next() is NopExpr)
            if let elc = expLocName {
                XCTAssertEqual(try XCTUnwrap(i.target as? VariableNameExpr).name, elc)
            } else {
                XCTAssertNil(i.target)
            }
        }

        try testParse("Listen", nil)
        try testParse("Listen ", nil)
        try testParse("L'isten ", nil)
        try testParse("Listen to my heart", "my heart")
    }

    func testOutput() throws {
        func testParse<T>(_ inp: String) throws -> T {
            var p = try XCTUnwrap(self.parse(inp))
            let o = try XCTUnwrap(p.next() as? VoidCallExpr)
            XCTAssertEqual(o.head, .print)
            let t = try XCTUnwrap(o.source as? T)
            XCTAssert(try p.next() is NopExpr)
            return t
        }

        let _: VariableNameExpr = try testParse("Shout my name")
        let _: VariableNameExpr = try testParse("whisper my name")
        let _: VariableNameExpr = try testParse("scream my name")
        let _: VariableNameExpr = try testParse("say my name") // Heisenberg
        let _: BoolExpr = try testParse("whisper yes")
        let _: PronounExpr = try testParse("shout it")
    }

    func testIncDecrement() throws {
        func testParse<T>(_ inp: String, _ value: Int) throws -> T {
            var p = try XCTUnwrap(self.parse(inp))
            let o = try XCTUnwrap(p.next() as? VoidCallExpr)
            XCTAssertEqual(o.head, .assign)
            let t = try XCTUnwrap(o.target as? T)
            let s = try XCTUnwrap(o.source as? FunctionCallExpr)
            XCTAssertEqual(s.head, .add)
            let _ = try XCTUnwrap(s.args[0] as? T)
            let v = try XCTUnwrap(s.args[1] as? NumberExpr)
            XCTAssertEqual(v.literal, Double(value))
            return t
        }

        let _: VariableNameExpr = try testParse("build me", 0)
        let _: VariableNameExpr = try testParse("build me up", 1)
        let _: VariableNameExpr = try testParse("build me up up", 2)
        let _: VariableNameExpr = try testParse("build me up up, up & up", 4)

        let _: PronounExpr = try testParse("knock him", 0)
        let _: PronounExpr = try testParse("knock him down", -1)
        let _: PronounExpr = try testParse("knock him down, down", -2)
        let _: IndexingExpr = try testParse("knock him at 0 down,down down", -3)
    }

    func testPush() throws {
        func testParse(_ inp: String, _ val: Double?) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let o = try XCTUnwrap(p.next() as? VoidCallExpr)
            XCTAssertEqual(o.head, .push)
            _ = try XCTUnwrap(o.target as? VariableNameExpr)
            if let v = val {
                let vv = try XCTUnwrap(o.arg as? NumberExpr)
                XCTAssertEqual(vv.literal, v)
            }
        }

        try testParse("rock the boat", nil)
        try testParse("rock the boat with 5", 5)
        try testParse("(i) push my fingers (into my eyes)", nil)
        try testParse("rock the boat like a g .six", 11.3)
    }

    func testPop() throws {
        func testParse(_ inp: String) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let o = try XCTUnwrap(p.next() as? FunctionCallExpr)
            XCTAssertEqual(o.head, .pop)
            _ = try XCTUnwrap(o.args[0] as? VariableNameExpr)
        }

        try testParse("roll the boat")
        try testParse("pop a rock")
    }

    func testIndexing() throws {
        func testParse<S,I>(_ inp: String) throws -> (S,I) {
            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(p.next() as? IndexingExpr)
            let s = try XCTUnwrap(i.source as? S)
            let ii = try XCTUnwrap(i.operand as? I)
            return (s,ii)
        }

        let _: (VariableNameExpr, NumberExpr) = try testParse("A horse at 5")
        let _: (PronounExpr, PronounExpr) = try testParse("him at her")
        let _: (VariableNameExpr, StringExpr) = try testParse("heaven at \"hell\"")
        let _: (StringExpr, StringExpr) = try testParse("\"heaven\" at \"hell\"")
        let _: (StringExpr, VariableNameExpr) = try testParse("\"heaven\" at hell")
    }

    func testArithmetic() throws {
        func stringifyParse(_ inp: String) throws -> String {
            func str(_ op: FunctionCallExpr.Op) -> String {
                switch op {
                case .add: return "+"
                case .sub: return "-"
                case .div: return "/"
                case .mul: return "*"
                case .and: return "&&"
                case .orr: return "||"
                case .nor: return "|!|"
                case .not: return "!"
                case .eq:  return "=="
                case .neq: return "!="
                case .leq: return "<="
                case .geq: return ">="
                case .lt:  return "<"
                case .gt:  return ">"
                case .custom: return ": "
                default: return "?"
                }
            }
            func str(_ e: ExprP) -> String {
                switch e {
                case let n as NumberExpr: return str(n)
                case let f as FunctionCallExpr: return str(f)
                case let v as VariableNameExpr: return str(v)
                case let l as ListExpr: return str(l)
                default: return "(?)"
                }
            }
            func str(_ n: NumberExpr) -> String { String(Int(n.literal)) }
            func str(_ v: VariableNameExpr) -> String { v.name }
            func str(_ l: ListExpr) -> String {
                l.members.map { str($0) }.joined(separator: ",")
            }
            func str(_ f: FunctionCallExpr) -> String {
                if f.args.count == 2 {
                    return "(\(str(f.args[0]))\(str(f.head))\(str(f.args[1])))"
                } else if f.args.count == 1 {
                    return "(\(str(f.head))\(str(f.args[0])))"
                }
                return "??"
            }

            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(p.next() as? FunctionCallExpr)
            _ = try XCTUnwrap(p.next() as? NopExpr)
            return str(i)
        }
        func testParse(_ inp: String, _ exp: String) throws {
            let got = try stringifyParse(inp)
            XCTAssertEqual(got, exp)
        }

        try testParse("1 with 2", "(1+2)")
        try testParse("1 with 2 of 3", "(1+(2*3))")
        try testParse("1 with 2 of 3 over 4", "(1+((2*3)/4))")
        try testParse("1 with 2 of 3 without 4", "((1+(2*3))-4)")
        try testParse("3 over 4 over 5", "((3/4)/5)")
        try testParse("3 over 4 minus 5", "((3/4)-5)")
        try testParse("3 over 4 minus 5 between 6", "((3/4)-(5/6))")
        try testParse("1 with 2 nor 3", "((1+2)|!|3)")
        try testParse("not 1", "(!1)")
        try testParse("not 1 or 2", "((!1)||2)")
        try testParse("1 of not 2", "(1*(!2))")
        try testParse("1 of not 2 over 3", "((1*(!2))/3)")
        try testParse("3 over 4 is 5 between 6", "((3/4)==(5/6))")
        try testParse("3 over 4 isn't 5 between 6", "((3/4)!=(5/6))")
        try testParse("3 with 4 isn't 5 and 6", "(((3+4)!=5)&&6)")
        try testParse("3 with 4 is not 5 with not 6", "((3+4)==((!5)+(!6)))")
        try testParse("3 over 4 is greater than 5 between 6", "((3/4)>(5/6))")
        try testParse("3 over 4 is less than 5 between 6", "((3/4)<(5/6))")
        try testParse("3 over 4 is as small as 5 between 6", "((3/4)<=(5/6))")
        try testParse("3 over 4 is as high as 5 between 6", "((3/4)>=(5/6))")
        try testParse("Midnight taking my world, Fire is 0 and Midnight taking my world, Hate is 0",
            "(((midnight: my world,fire)==0)&&((midnight: my world,hate)==0))")
    }

    func testList() throws {
        func testParse(_ inp: String, _ exp: [Any]) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(p.next() as? ListExpr)
            XCTAssertEqual(i.members.count, exp.count)
            for (m,e) in zip(i.members, exp) {
                if let ee = e as? Int {
                    let mm = try XCTUnwrap(m as? NumberExpr)
                    XCTAssertEqual(mm.literal, Double(ee))
                } else {
                    let ee = e as! [Any]
                    let mm = try XCTUnwrap(m as? FunctionCallExpr)
                    XCTAssertEqual(mm.head, .and)
                    for i in 0...1 {
                        let eee = ee[i] as! Int
                        let mmm = try XCTUnwrap(mm.args[i] as? NumberExpr)
                        XCTAssertEqual(mmm.literal, Double(eee))
                    }
                }
            }
        }
        try testParse("5, 6 & 7, and 8, 9 & 10", [5,6,7,8,9,10])
        try testParse("5, 6 and 7, and 8", [5,[6,7],8])
        try testParse("5, 6 & 7, and 8, ", [5,6,7,8])
        try testParse("5, 6 ", [5,6])
    }

    func testListReduction() throws {
        func testParse(_ inp: String, _ exp: Double) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(p.next() as? NumberExpr)
            XCTAssertEqual(i.literal, exp)
        }
        try testParse("5,", 5)
    }

    func testRounding() throws {
        func testParse(_ inp: String, _ dir: VoidCallExpr.Op) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(p.next() as? VoidCallExpr)
            XCTAssertEqual(i.head, dir)
        }
        try testParse("turn up hell", .ceil)
        try testParse("turn down heaven", .floor)
        try testParse("turn round partner", .round)
        try testParse("turn it up", .ceil)
        try testParse("turn him down", .floor)
        try testParse("turn it around", .round)
    }

    func testCasting() throws {
        func testParse(_ inp: String, _ target: ExprP.Type, _ source: ExprP.Type?, _ arg: ExprP.Type?) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(p.next() as? VoidCallExpr)
            XCTAssertEqual(i.head, .cast)
            XCTAssert(target == type(of: i.target!))
            if let source = source {
                XCTAssert(source == type(of: i.source!))
            }
            if let arg = arg {
                XCTAssert(arg == type(of: i.arg!))
            }
        }
        try testParse("cast my life", VariableNameExpr.self, nil, nil)
        try testParse("burn my life with 5", VariableNameExpr.self, nil, NumberExpr.self)
        try testParse("cast my dream into my life", VariableNameExpr.self, VariableNameExpr.self, nil)
        try testParse("cast my dream into my life with 5", VariableNameExpr.self, VariableNameExpr.self, NumberExpr.self)
        try testParse("cast 5 into my life", VariableNameExpr.self, NumberExpr.self, nil)
    }

    func testFuncCall() throws {
        func testParse(_ inp: String, _ head: ExprP.Type, _ ex: ExprP.Type) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(p.next() as? FunctionCallExpr)
            XCTAssertEqual(i.head, .custom)
            XCTAssert(type(of: i.args[0]) == head)
            XCTAssert(type(of: i.args[1]) == ex)
        }
        try testParse("my life taking 5", VariableNameExpr.self, NumberExpr.self)
        try testParse("it taking work", PronounExpr.self, VariableNameExpr.self)
        try testParse("my life taking 5, and 6", VariableNameExpr.self, ListExpr.self)
    }

    func testLoop() throws {
        func testParse(_ inp: String, inverted: Bool, inner: Int, outer: Int) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(p.next() as? LoopExpr)
            if inverted {
                let c = try XCTUnwrap(i.condition as? FunctionCallExpr)
                XCTAssertEqual(c.head, .not)
            }
            XCTAssertEqual(i.loopBlock.count, inner)
            for _ in 0..<outer {
                XCTAssertNotNil(try? p.next())
            }
            XCTAssertNil(try p.next())
        }
        try testParse("while 1", inverted: false, inner: 0, outer: 0)
        try testParse("while 1\n", inverted: false, inner: 0, outer: 0)
        try testParse("while 1\n1", inverted: false, inner: 1, outer: 0)
        try testParse("while 1\n1\n1", inverted: false, inner: 2, outer: 0)
        try testParse("while 1\n\n1", inverted: false, inner: 0, outer: 2)
        try testParse("while 1\n1\n\n1", inverted: false, inner: 1, outer: 2)
        try testParse("while 1\n1\n1\n\n1", inverted: false, inner: 2, outer: 2)
        try testParse("until 1", inverted: true, inner: 0, outer: 0)
    }

    func testCondition() throws {
        func testParse(_ inp: String, if iff: Int, else lse: Int, outer: Int) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(p.next() as? ConditionalExpr)
            XCTAssertEqual(i.trueBlock.count, iff)
            XCTAssertEqual(i.falseBlock.count, lse)
            for _ in 0..<outer {
                XCTAssertNotNil(try? p.next())
            }
            XCTAssertNil(try p.next())
        }
        try testParse("if 0", if: 0, else: 0, outer: 0)
        try testParse("if 0\n1", if: 1, else: 0, outer: 0)
        try testParse("if 0\n1\n1", if: 2, else: 0, outer: 0)
        try testParse("if 0\n1\n1\nelse\n1", if: 2, else: 1, outer: 0)
        try testParse("if 0\n1\nelse\n1\n1", if: 1, else: 2, outer: 0)
        try testParse("if 0\nelse\n1\n1\n1", if: 0, else: 3, outer: 0)
        try testParse("if 0\n\nelse\n1\n1\n1", if: 0, else: 0, outer: 5)
    }

    func testFuncDecl() throws {
        func testParse(_ inp: String, args: Int, inner: Int, outer: Int) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(p.next() as? FunctionDeclExpr)
            XCTAssertEqual(i.args.count, args)
            XCTAssertEqual(i.funBlock.count, inner)
            for _ in 0..<outer {
                XCTAssertNotNil(try? p.next())
            }
            XCTAssertNil(try p.next())
        }
        try testParse("my life takes work", args: 1, inner: 0, outer: 0)
        try testParse("my life takes work\n", args: 1, inner: 0, outer: 0)
        try testParse("my life takes work\n1", args: 1, inner: 1, outer: 0)
        try testParse("my life takes work\n1\n1", args: 1, inner: 2, outer: 0)
        try testParse("my life takes work\n1\n1\n\n1", args: 1, inner: 2, outer: 2)
        try testParse("my life takes work, my sanity & money\n1", args: 3, inner: 1, outer: 0)
    }

    func testReturn() throws {
        func testParse(_ inp: String) throws {
            var p = try XCTUnwrap(self.parse(inp))
            let i = try XCTUnwrap(p.next() as? ReturnExpr)
            _ = try XCTUnwrap(i.value as? PronounExpr)
        }
        try testParse("give it")
        try testParse("give it back")
        try testParse("give back it")
        try testParse("send it")
        try testParse("send it back")
        try testParse("return it")
        try testParse("return it back")
    }

    func testElse() throws {
        var p = try XCTUnwrap(self.parse("else"))
        _ = try XCTUnwrap(p.next() as? ElseExpr)
    }

    func testBreak() throws {
        func testParse(_ inp: String) throws {
            var p = try XCTUnwrap(self.parse(inp))
            _ = try XCTUnwrap(p.next() as? BreakExpr)
        }
        try testParse("break")
        try testParse("break it down")
    }

    func testContinue() throws {
        func testParse(_ inp: String) throws {
            var p = try XCTUnwrap(self.parse(inp))
            _ = try XCTUnwrap(p.next() as? ContinueExpr)
        }
        try testParse("continue")
        try testParse("take it to the top")
    }

    func testFizzBuzz() throws {
        func parseDiscardAll(_ inp: String) throws {
            var p = Parser(input: inp)
            while let _ = try p.next() {}
        }
        let fizzbuzz = try! String(contentsOf: URL(fileURLWithPath: "./Tests/fizzbuzz.rock"))

        try parseDiscardAll(fizzbuzz)
    }
}
