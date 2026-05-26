// AST.swift — PLAIN abstract syntax tree

// MARK: — Top level

struct Program {
    var declarations: [Declaration]
}

// MARK: — Declarations

indirect enum Declaration {
    case function(FunctionDecl)
    case taskFunction(TaskFunctionDecl)
    case classDecl(ClassDecl)
    case featureDecl(FeatureDecl)
    case errorDecl(ErrorDecl)
    case letDecl(LetDecl)
    case varDecl(VarDecl)
    case sharedVarDecl(SharedVarDecl)
    case statement(Statement)
}

struct FunctionDecl {
    let name:       String
    let params:     [Parameter]
    let returnType: TypeAnnotation?
    let body:       [Statement]
    let line:       Int
}

struct TaskFunctionDecl {
    let name:       String
    let params:     [Parameter]
    let returnType: TypeAnnotation?
    let body:       [Statement]
    let line:       Int
}

struct Parameter {
    let preposition: String?
    let name:        String
    let type:        TypeAnnotation
}

struct ClassDecl {
    let name:        String
    let parent:      String?
    let features:    [String]
    let properties:  [PropertyDecl]
    let initialiser: InitDecl?
    let methods:     [FunctionDecl]
    let codable:     CodableDecl?
    let line:        Int
}

struct PropertyDecl {
    let name:       String
    let type:       TypeAnnotation
    let mapping:    String?
}

struct InitDecl {
    let params: [Parameter]
    let body:   [Statement]
}

struct CodableDecl {
    let decode: [Statement]?
    let encode: [Statement]?
}

struct FeatureDecl {
    let name:    String
    let methods: [FunctionSignature]
    let line:    Int
}

struct FunctionSignature {
    let name:       String
    let params:     [Parameter]
    let returnType: TypeAnnotation?
}

struct ErrorDecl {
    let name:   String
    let params: [Parameter]
    let line:   Int
}

struct LetDecl {
    let name:  String
    let type:  TypeAnnotation?
    let value: Expression
    let line:  Int
}

struct VarDecl {
    let name:  String
    let type:  TypeAnnotation?
    let value: Expression?
    let line:  Int
}

struct SharedVarDecl {
    let name:  String
    let type:  TypeAnnotation?
    let value: Expression?
    let line:  Int
}

// MARK: — Type annotations

indirect enum TypeAnnotation: Equatable {
    case named(String)
    case listOf(TypeAnnotation)
    case mapOf(TypeAnnotation, TypeAnnotation)
    case channelOf(TypeAnnotation)
    case optional(TypeAnnotation)
    case sendChannel(TypeAnnotation)
    case receiveChannel(TypeAnnotation)
}

// MARK: — Statements

indirect enum Statement {
    case set(SetStatement)
    case returnStmt(ReturnStatement)
    case ifStmt(IfStatement)
    case whileStmt(WhileStatement)
    case forRange(ForRangeStatement)
    case forEach(ForEachStatement)
    case parallel(ParallelStatement)
    case tryCatch(TryCatchStatement)
    case throwStmt(ThrowStatement)
    case print(PrintStatement)
    case send(SendStatement)
    case close(CloseStatement)
    case run(RunStatement)
    case add(AddStatement)
    case remove(RemoveStatement)
    case createDirectory(Expression)
    case write(WriteStatement)
    case append(AppendStatement)
    case deleteFile(Expression)
    case deleteDirectory(Expression)
    case copyFile(from: Expression, to: Expression)
    case moveFile(from: Expression, to: Expression)
    case exitStmt(ExitStatement)
    case clearTerminal
    case expression(Expression)
}

struct SetStatement {
    let target: LValue
    let value:  Expression
    let line:   Int
}

indirect enum LValue {
    case variable(String)
    case property(Expression, String)
    case listItem(index: Expression, list: Expression)
    case mapEntry(key: Expression, map: Expression)
}

struct ReturnStatement {
    let value: Expression?
    let line:  Int
}

struct IfStatement {
    let condition:  Expression
    let thenBody:   [Statement]
    let elseIfs:    [(Expression, [Statement])]
    let elseBody:   [Statement]?
    let line:       Int
}

struct WhileStatement {
    let condition: Expression
    let body:      [Statement]
    let line:      Int
}

struct ForRangeStatement {
    let variable: String
    let from:     Expression
    let to:       Expression
    let body:     [Statement]
    let line:     Int
}

struct ForEachStatement {
    let variable:   String
    let collection: Expression
    let body:       [Statement]
    let line:       Int
}

struct ParallelStatement {
    let declarations: [Declaration]
    let line:         Int
}

struct TryCatchStatement {
    let body:    [Statement]
    let catches: [CatchClause]
    let line:    Int
}

struct CatchClause {
    let errorType: String?
    let binding:   String
    let body:      [Statement]
}

struct ThrowStatement {
    let errorName: String
    let args:      [(String, Expression)]
    let line:      Int
}

struct PrintStatement {
    let value:       Expression
    let destination: PrintDestination
    let color:       Expression?
    let style:       TextStyle?
    let line:        Int
}

enum PrintDestination {
    case standard
    case error
}

enum TextStyle {
    case bold, italic, underline, dim
}

struct SendStatement {
    let value:   Expression
    let channel: Expression
    let line:    Int
}

struct CloseStatement {
    let channel: Expression
    let line:    Int
}

struct RunStatement {
    let name: String
    let args: [(String?, Expression)]
    let line: Int
}

struct AddStatement {
    let value:      Expression
    let collection: Expression
    let line:       Int
}

struct RemoveStatement {
    let value:      Expression
    let collection: Expression
    let line:       Int
}

struct WriteStatement {
    let content: Expression
    let path:    Expression
    let line:    Int
}

struct AppendStatement {
    let content: Expression
    let path:    Expression
    let line:    Int
}

struct ExitStatement {
    let code: Expression
    let line: Int
}

// MARK: — Expressions

indirect enum Expression {
    // Literals
    case text(String)
    case number(Int)
    case decimal(Double)
    case bool(Bool)
    case nothing

    // References
    case identifier(String)
    case this

    // Access
    case propertyAccess(Expression, String)
    case methodCall(Expression, String, [(String?, Expression)])
    case functionCall(String, [(String?, Expression)])
    case awaitExpr(Expression)

    // Operators
    case binary(Expression, BinaryOp, Expression)
    case unary(UnaryOp, Expression)

    // Inline conditional
    case inlineIf(condition: Expression, then: Expression, else: Expression)

    // Collections
    case listLiteral([Expression])
    case dictionaryLiteral([(Expression, Expression)])

    // Standard library expressions
    case stdlibCall(StdlibExpr)
}

enum BinaryOp: String {
    case add = "+", subtract = "-", multiply = "*", divide = "/"
    case equal = "is", notEqual = "is not"
    case greater = ">", less = "<", greaterEqual = ">=", lessEqual = "<="
    case and = "and", or = "or"
    case inCollection = "in"
    case isPrefix = "is prefix of", isSuffix = "is suffix of"
}

enum UnaryOp {
    case not, negate
}

// Standard library expression nodes
indirect enum StdlibExpr {
    // Text
    case uppercase(Expression)
    case lowercase(Expression)
    case trim(Expression)
    case reverseText(Expression)
    case replacement(old: Expression, new: Expression, in: Expression)
    case lengthOf(Expression)
    case positionsOf(Expression, in: Expression)
    case substring(Expression, from: Expression, to: Expression)
    case characterAt(Expression, in: Expression)
    case partsOf(Expression, by: Expression)
    case wordsOf(Expression)
    case linesOf(Expression)
    case joinOf(Expression, with: Expression?)
    case leftPadding(Expression, to: Expression, with: Expression?)
    case rightPadding(Expression, to: Expression, with: Expression?)
    case textFrom(Expression)
    case numberFrom(Expression)
    case decimalFrom(Expression)

    // Number
    case round(Expression, places: Expression?)
    case floor(Expression, places: Expression?)
    case ceiling(Expression, places: Expression?)
    case absolute(Expression)
    case squareRoot(Expression)
    case powerOf(Expression, Expression)
    case remainder(Expression, by: Expression)
    case minimum(Expression, Expression?)
    case maximum(Expression, Expression?)

    // Collections
    case sortOf(Expression, by: Expression?, descending: Bool)
    case filterOf(Expression, where: Expression)
    case countOf(Expression, where: Expression?)
    case sumOf(Expression)
    case averageOf(Expression)
    case firstOf(Expression, where: Expression)
    case lastOf(Expression, where: Expression)
    case anyOf(Expression, where: Expression)
    case allOf(Expression, where: Expression)
    case uniqueOf(Expression)
    case combinationOf(Expression, Expression)
    case shuffleOf(Expression)
    case reverseOf(Expression)
    case itemAt(Expression, in: Expression)

    // Moment
    case currentMoment
    case momentOf(year: Expression, month: Expression, day: Expression,
                  hour: Expression?, minute: Expression?,
                  second: Expression?, millisecond: Expression?)
    case momentAfter(Expression, amount: Expression, unit: TimeUnit)
    case momentBefore(Expression, amount: Expression, unit: TimeUnit)
    case yearOf(Expression)
    case monthOf(Expression)
    case dayOf(Expression)
    case hourOf(Expression)
    case minuteOf(Expression)
    case secondOf(Expression)
    case millisecondOf(Expression)
    case diffBetween(Expression, Expression, unit: TimeUnit)
    case textFromMoment(Expression, format: Expression)
    case momentFrom(Expression, format: Expression?)

    // File system
    case pathOf([Expression])
    case nameOf(Expression)
    case extensionOf(Expression)
    case fullNameOf(Expression)
    case parentOf(Expression)
    case homeDirectory
    case temporaryDirectory
    case currentDirectory
    case textFromPath(Expression)
    case contentsOfFile(Expression)
    case sizeOfFile(Expression)
    case modificationDate(Expression)
    case fileExists(Expression)
    case directoryExists(Expression)
    case contentsOfDirectory(Expression)

    // Networking
    case httpGet(url: Expression, headers: [(String, Expression)])
    case httpPost(url: Expression, body: Expression, headers: [(String, Expression)])
    case httpPut(url: Expression, body: Expression, headers: [(String, Expression)])
    case httpPatch(url: Expression, body: Expression, headers: [(String, Expression)])
    case httpDelete(url: Expression, headers: [(String, Expression)])
    case statusOf(Expression)
    case bodyOf(Expression)
    case headerOf(String, Expression)

    // JSON
    case parseJson(Expression)
    case jsonObject
    case jsonArrayWith([Expression])
    case jsonOf(Expression)
    case textOfJsonKey(String, in: Expression)
    case numberOfJsonKey(String, in: Expression)
    case boolOfJsonKey(String, in: Expression)
    case objectOfJsonKey(String, in: Expression)
    case listOfJsonKey(String, in: Expression)
    case decodeAs(String, from: Expression)
    case decodeListAs(String, from: Expression)

    // Terminal
    case widthOfTerminal
    case heightOfTerminal
    case inputWith(prompt: Expression?)

    // Environment
    case valueOfEnvironment(Expression)
    case arguments
    case operatingSystem

    // Random
    case randomNumber(min: Expression?, max: Expression?)
    case randomDecimal
    case randomBool
    case randomItemIn(Expression)
}

enum TimeUnit {
    case years, months, weeks, days, hours, minutes, seconds, milliseconds
}
