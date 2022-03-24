# GetSchwifty

Have you been hired as a Rockstar developer, but now your company wants you to develop in this weird, esoteric language called Swift?
Fear not, GetSchwifty is here to save you.
It is a probably full-featured Rockstar interpreter written in Swift.

## Usage
The interface is quite easy.
It exposes:
```swift
public struct GetSchwifty {
    public var maxLoopIterations: UInt?

    init(input: String, rockin: Rockin? = nil, rockout: Rockout? = nil) throws
    func run(rockin: Rockin? = nil, rockout: Rockout? = nil) throws
}
```
where:
```swift
public typealias Rockin = () throws -> Any?
public typealias Rockout = (Any?) throws -> Void
```
Pass a Rockstar program as the `input` String to the constructor of `GetSchwifty`, and call `run` to run the program.
Use the `rockin` and `rockout` parameters as callback functions for Rockstars `listen` and `shout` constructs.
You can `run` the program multiple times with different `rockin` and `rockout` functions or fall back to the functions passed in the constructor.
If you never specify `rockin` or `rockout`, every Rockstar call to `listen` will be handled like a `nil` input and `shout` will do nothing.
Shout into the void, if you will.

You can use the `maxLoopIterations` property if you tend to fuck up your Rockstar programs, like I do, and run into endless loops constantly.
If the property is set, loops in your Rockstar program will throw a `RuntimeError` if they run too long, i.e. more iterations than `maxLoopIterations`.

While we're at `RuntimeError`, GetSchwifty also exposes three `Error` types:
```swift
public protocol RockstarError: Error, CustomStringConvertible {
    var errorPos: (UInt, UInt) { get }
}
public protocol ParserError: RockstarError {}
public protocol RuntimeError: RockstarError {}
```
You can catch these to handle syntactical (`ParserError`) or semantical (`RuntimeError`) errors.
The `errorPos` property should give you a good hint about where you fucked up.
The first tuple value will represent the line (starting at 1), and the second one will represent the character offset within the line (starting at 0, because counting chars from 1 just feels wrong).
As these `Errors` comply to `CustomStringConvertible`, the `description` property should also give you a textual representation of what went wrong.

A special type and its singleton to represent uninitialised Rockstar variables are also exposed:
```swift
public struct Rockstar {
    public struct Mysterious: Equatable {}
    static public let mysterious = Mysterious()
}
```

## How it works
To use PM words: magically.
To be a bit more technical:
I tried to implement it as close to the spec as possible.
If the spec was ambiguous or not complete I tried to implement what the reference implementation does.

The spec can be found at https://codewithrockstar.com/docs and the reference implementation at https://codewithrockstar.com/online.

My implementation handles evaluation of Rockstar code in three steps.
1. Lexing the input, i.e. interpreting the stream of `input` characters as tokens/lexemes.
1. Parsing the lexemes, i.e. building a syntax tree from the lexemes.
1. Evaluating the syntax tree.

Step 2 may throw `ParserError`s, step 3 may throw `RuntimeError`s.
Lexing is handled failure free. This is done by handling invalid input characters like whitespace.

### Limitations compared to the reference implementation
* The `and` keyword in Rockstar code is always interpreted as a boolean and (`&&`), except when preceded by a `,`.
The reference implementation will happily parse something like:
```rockstar
midnight takes your heart and your soul
```
My implementation will throw an error, because this will be interpreted as:
```swift
func midnight(yourHeart: Any && yourSoul: Any) { ... }
```
Does not make sense, does it.
What we need is a list of arguments, so instead you need to write:
```rockstar
midnight takes your heart, and your soul
```
This will be correctly intepreted as:
```swift
func midnight(yourHeart: Any, yourSoul: Any) { ... }
```

* The reference implementation will interpret
```rockstar
midnight taking your heart with your soul
```
as
```swift
midnight(yourHeart + yourSoul)
```
while my implementation will parse it as:
```swift
midnight(yourHeart) + yourSoul
```
It should be noted that my implementation behaves according to the spec in that case, and that the reference implementation seems to be bugged.

### Other notable implementation details
You may have noticed that the `Rockin` closures take `Any?` and `Rockout` closures return `Any?`.
In practice you should be prepared to receive `String`, `Int`, `Double`, `Rockstar.Mysterious`, `[Any]`, `[AnyHashable: Any]`, and `nil`.

Maybe I will add a protocol for that in the future.

Apart from these types you can also pass closures with the following signatures into `Rockin` and call them from Rockstar:
```swift
() throws -> Void
([Any]) throws -> Void
() throws -> Any
() throws -> Any?
([Any]) throws -> Any
([Any]) throws -> Any?
```

Rockstar functions are first class members, so `f takes x,y` will create a variable called `f` that can be used like any other variable and can be passed around.
Functions can also be nested.

String literals can interpret some escape sequences, namely `\n`, `\r`, `\t`, `\\`, and `\"`.
Also string literals as well as comments may span multiple lines.

#### A note about scopes
When you define a variable in Rockstar it will be defined in the narrowest scope possible, i.e. within the current if/else-statement or loop, the current function, or globally, in that order.
If you do write to a variable, it will however be looked up in the scope hierarchy and a new variable will only be defined if a variable of that name can't be found.

## Q&A
### What should I use this for?
Honestly, for nothing, really. Rockstar is a language that inherits many of its rules from a terrible language called JavaScript which should never be used either.
If you really want to, you could however use it to implement a PlugIn sytem for your Program that takes Rockstar as input. You know, if you're not into Python or Lua or anything.
But if you decide to use it, do not blame me if it turns out to be a horrible idea. See also `COPYING`.

### Why?
40% because I can, 30% to prove myself I can, 15% to improve my Swift skills, 10% to write this document, and 5% because winter evenings are dark and full of terrors.

### Where can I find further documentation?
About Rockstar? See the links above. About GetSchwifty? Oh boy... Look at the code. Especially the tests. I'm happy to announce that due to me elite rockstar developing skills my code is so self-documenting it does not contain one line of comments. I mean, this is Rock'n'Roll, not rocket science.

### Is it an LL- or an LR-parser?
The fuck do I know. I told you this is not rocket science. But I'm happy to anounce it is a real parser, that does not rely on regualar expressions.

### You do realize there are parser generators?
I do, but where is the fun in that.

### What's the dependencies?
None. Not even `Foundation`.

### What Swift version does it require?
I developed it on 5.5, but I believe it should run on 5.4 as well. Maybe even before that.

### Why does xy not work?
Probably because my developer skills are not as elite as I thought they were.

### Can you also make a Rockstar to Swift transpiler? I'm a Rockstar developer and don't want to learn Swift!
Probably. In theory, only the evaluation step needs to be exchanged by a code generation step. But that sounds like a lot of work, and I'm not feeling like it right now. Maybe next winter.
