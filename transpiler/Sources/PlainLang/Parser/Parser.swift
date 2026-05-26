// Parser.swift — PLAIN [Token] → Program AST

struct ParseError: Error {
    let message: String
    let line:    Int
    let column:  Int
}

struct Parser {

    private var tokens:  [Token]
    private var pos:     Int = 0

    init(tokens: [Token]) {
        self.tokens = tokens.filter {
            // Remove bare newlines that follow indent/dedent — simplifies grammar
            if case .newline = $0.kind { return true }
            return true
        }
    }

    // MARK: — Entry point

    mutating func parse() throws -> Program {
        var declarations: [Declaration] = []
        while !isAtEnd {
            skipNewlines()
            if isAtEnd { break }
            declarations.append(try parseDeclaration())
        }
        return Program(declarations: declarations)
    }

    // MARK: — Declarations

    private mutating func parseDeclaration() throws -> Declaration {
        let tok = current

        switch tok.kind {
        case .kwFunction:
            return .function(try parseFunctionDecl())

        case .kwTask:
            return .taskFunction(try parseTaskFunctionDecl())

        case .kwClass:
            return .classDecl(try parseClassDecl())

        case .kwFeature:
            return .featureDecl(try parseFeatureDecl())

        case .kwError:
            return .errorDecl(try parseErrorDecl())

        case .kwLet:
            return .letDecl(try parseLetDecl())

        case .kwVar:
            return .varDecl(try parseVarDecl())

        case .kwShared:
            return .sharedVarDecl(try parseSharedVarDecl())

        default:
            return .statement(try parseStatement())
        }
    }

    // MARK: — Function declarations

    private mutating func parseFunctionDecl() throws -> FunctionDecl {
        let l = current.line
        try consume(.kwFunction)
        let name = try consumeIdentifier()
        let params = try parseParamList()
        var returnType: TypeAnnotation? = nil
        if matches(.kwReturns) {
            advance()
            returnType = try parseTypeAnnotation()
        }
        skipNewlines()
        let body = try parseBody()
        return FunctionDecl(name: name, params: params, returnType: returnType, body: body, line: l)
    }

    private mutating func parseTaskFunctionDecl() throws -> TaskFunctionDecl {
        let l = current.line
        try consume(.kwTask)
        try consume(.kwFunction)
        let name = try consumeIdentifier()
        let params = try parseParamList()
        var returnType: TypeAnnotation? = nil
        if matches(.kwReturns) {
            advance()
            returnType = try parseTypeAnnotation()
        }
        skipNewlines()
        let body = try parseBody()
        return TaskFunctionDecl(name: name, params: params, returnType: returnType, body: body, line: l)
    }

    private mutating func parseParamList() throws -> [Parameter] {
        var params: [Parameter] = []
        while !isAtEnd && !matches(.kwReturns) && !matches(.newline) && !matches(.indent) {
            let param = try parseParameter()
            params.append(param)
            if matches(.comma) { advance() }
        }
        return params
    }

    private mutating func parseParameter() throws -> Parameter {
        // Optional preposition (any non-type keyword or identifier before the name)
        var preposition: String? = nil
        if isPreposition(current) {
            preposition = tokenText(current)
            advance()
        }
        let name = try consumeIdentifier()
        try consume(.kwAs)
        let type = try parseTypeAnnotation()
        return Parameter(preposition: preposition, name: name, type: type)
    }

    // MARK: — Class declarations

    private mutating func parseClassDecl() throws -> ClassDecl {
        let l = current.line
        try consume(.kwClass)
        let name = try consumeIdentifier()

        var parent: String? = nil
        if matches(.kwExtends) {
            advance()
            parent = try consumeIdentifier()
        }

        var features: [String] = []
        if matches(.kwIs) {
            advance()
            features.append(try consumeIdentifier())
            while matches(.kwAnd) {
                advance()
                features.append(try consumeIdentifier())
            }
        }

        skipNewlines()
        try consume(.indent)

        var properties:  [PropertyDecl] = []
        var initialiser: InitDecl?      = nil
        var methods:     [FunctionDecl] = []
        var codable:     CodableDecl?   = nil

        while !matches(.dedent) && !isAtEnd {
            skipNewlines()
            switch current.kind {
            case .kwProperty:
                properties.append(try parsePropertyDecl())
            case .kwInit:
                initialiser = try parseInitDecl()
            case .kwFunction:
                methods.append(try parseFunctionDecl())
            case .kwDecode, .kwEncode:
                codable = try parseCodableDecl(existing: codable)
            default:
                throw parseError("Unexpected token in class body: \(current.description)")
            }
            skipNewlines()
        }

        try consume(.dedent)
        return ClassDecl(
            name: name, parent: parent, features: features,
            properties: properties, initialiser: initialiser,
            methods: methods, codable: codable, line: l
        )
    }

    private mutating func parsePropertyDecl() throws -> PropertyDecl {
        try consume(.kwProperty)
        let name = try consumeIdentifier()
        try consume(.kwAs)
        let type = try parseTypeAnnotation()
        var mapping: String? = nil
        if matches(.kwMapping) {
            advance()
            guard case .textLiteral(let s) = current.kind else {
                throw parseError("Expected string after 'mapping'")
            }
            mapping = s
            advance()
        }
        skipNewlines()
        return PropertyDecl(name: name, type: type, mapping: mapping)
    }

    private mutating func parseInitDecl() throws -> InitDecl {
        try consume(.kwInit)
        let params = try parseParamList()
        skipNewlines()
        let body = try parseBody()
        return InitDecl(params: params, body: body)
    }

    private mutating func parseCodableDecl(existing: CodableDecl?) throws -> CodableDecl {
        var decode = existing?.decode
        var encode = existing?.encode
        if matches(.kwDecode) {
            advance()
            try consume(.kwFrom)
            _ = try consumeIdentifier() // data
            try consume(.kwAs)
            _ = try consumeIdentifier() // json
            skipNewlines()
            decode = try parseBody()
        } else if matches(.kwEncode) {
            advance()
            try consume(.kwReturns)
            _ = try consumeIdentifier() // json
            skipNewlines()
            encode = try parseBody()
        }
        return CodableDecl(decode: decode, encode: encode)
    }

    // MARK: — Feature declarations

    private mutating func parseFeatureDecl() throws -> FeatureDecl {
        let l = current.line
        try consume(.kwFeature)
        let name = try consumeIdentifier()
        skipNewlines()
        try consume(.indent)
        var methods: [FunctionSignature] = []
        while !matches(.dedent) && !isAtEnd {
            skipNewlines()
            try consume(.kwFunction)
            let mName = try consumeIdentifier()
            let params = try parseParamList()
            var returnType: TypeAnnotation? = nil
            if matches(.kwReturns) {
                advance()
                returnType = try parseTypeAnnotation()
            }
            methods.append(FunctionSignature(name: mName, params: params, returnType: returnType))
            skipNewlines()
        }
        try consume(.dedent)
        return FeatureDecl(name: name, methods: methods, line: l)
    }

    // MARK: — Error declarations

    private mutating func parseErrorDecl() throws -> ErrorDecl {
        let l = current.line
        try consume(.kwError)
        let name = try consumeIdentifier()
        let params = try parseParamList()
        skipNewlines()
        return ErrorDecl(name: name, params: params, line: l)
    }

    // MARK: — Variable declarations

    private mutating func parseLetDecl() throws -> LetDecl {
        let l = current.line
        try consume(.kwLet)
        let name = try consumeIdentifier()
        var type: TypeAnnotation? = nil
        if matches(.kwAs) {
            advance()
            type = try parseTypeAnnotation()
        }
        try consume(.kwBe)
        let value = try parseExpression()
        skipNewlines()
        return LetDecl(name: name, type: type, value: value, line: l)
    }

    private mutating func parseVarDecl() throws -> VarDecl {
        let l = current.line
        try consume(.kwVar)
        let name = try consumeIdentifier()
        var type: TypeAnnotation? = nil
        if matches(.kwAs) {
            advance()
            type = try parseTypeAnnotation()
        }
        var value: Expression? = nil
        if matches(.kwBe) {
            advance()
            value = try parseExpression()
        }
        skipNewlines()
        return VarDecl(name: name, type: type, value: value, line: l)
    }

    private mutating func parseSharedVarDecl() throws -> SharedVarDecl {
        let l = current.line
        try consume(.kwShared)
        try consume(.kwVar)
        let name = try consumeIdentifier()
        var type: TypeAnnotation? = nil
        if matches(.kwAs) {
            advance()
            type = try parseTypeAnnotation()
        }
        var value: Expression? = nil
        if matches(.kwBe) {
            advance()
            value = try parseExpression()
        }
        skipNewlines()
        return SharedVarDecl(name: name, type: type, value: value, line: l)
    }

    // MARK: — Type annotations

    private mutating func parseTypeAnnotation() throws -> TypeAnnotation {
        switch current.kind {
        case .kwText:    advance(); return .named("text")
        case .kwNumber:  advance(); return .named("number")
        case .kwDecimal: advance(); return .named("decimal")
        case .kwBool:    advance(); return .named("bool")
        case .kwPath:    advance(); return .named("path")
        case .kwMoment:  advance(); return .named("moment")
        case .kwResponse:advance(); return .named("response")
        case .kwJson:    advance(); return .named("json")
        case .nothing:   advance(); return .named("nothing")

        case .kwList:
            advance()
            try consume(.kwOf)
            let inner = try parseTypeAnnotation()
            return .listOf(inner)

        case .kwMap:
            advance()
            try consume(.kwOf)
            let key = try parseTypeAnnotation()
            try consume(.kwTo)
            let value = try parseTypeAnnotation()
            return .mapOf(key, value)

        case .kwChannel:
            advance()
            try consume(.kwOf)
            let inner = try parseTypeAnnotation()
            return .channelOf(inner)

        case .identifier(let name):
            advance()
            if matches(.kwOr) {
                advance()
                guard case .nothing = current.kind else {
                    throw parseError("Expected 'nothing' after 'or'")
                }
                advance()
                return .optional(.named(name))
            }
            return .named(name)

        default:
            // Check for named type followed by 'or nothing'
            if let name = currentIdentifierOrTypeName() {
                advance()
                if matches(.kwOr) {
                    advance()
                    guard case .nothing = current.kind else {
                        throw parseError("Expected 'nothing' after 'or'")
                    }
                    advance()
                    return .optional(.named(name))
                }
                return .named(name)
            }
            throw parseError("Expected type annotation, got \(current.description)")
        }
    }

    // MARK: — Body parsing

    private mutating func parseBody() throws -> [Statement] {
        try consume(.indent)
        var body: [Statement] = []
        while !matches(.dedent) && !isAtEnd {
            skipNewlines()
            if matches(.dedent) { break }
            body.append(try parseStatement())
            skipNewlines()
        }
        try consume(.dedent)
        return body
    }

    // MARK: — Statements (scaffold — key statements implemented)

    private mutating func parseStatement() throws -> Statement {
        let l = current.line
        switch current.kind {
        case .kwSet:      return .set(try parseSetStatement())
        case .kwReturn:   return .returnStmt(try parseReturnStatement())
        case .kwIf:       return .ifStmt(try parseIfStatement())
        case .kwWhile:    return .whileStmt(try parseWhileStatement())
        case .kwFor:      return try parseForStatement()
        case .kwParallel: return .parallel(try parseParallelStatement())
        case .kwTry:      return .tryCatch(try parseTryCatchStatement())
        case .kwThrow:    return .throwStmt(try parseThrowStatement())
        case .kwPrint:    return .print(try parsePrintStatement())
        case .kwSend:     return .send(try parseSendStatement())
        case .kwClose:    return .close(try parseCloseStatement())
        case .kwRun:      return .run(try parseRunStatement())
        case .kwAdd:      return .add(try parseAddStatement())
        case .kwRemove:   return .remove(try parseRemoveStatement())
        case .kwWrite:    return .write(try parseWriteStatement())
        case .kwAppend:   return .append(try parseAppendStatement())
        case .kwCreate:   return try parseCreateStatement()
        case .kwDelete:   return try parseDeleteStatement()
        case .kwCopy:     return try parseCopyStatement()
        case .kwMove:     return try parseMoveStatement()
        case .kwClear:    return try parseClearStatement()
        case .kwExit:     return .exitStmt(try parseExitStatement())
        default:
            let expr = try parseExpression()
            skipNewlines()
            return .expression(expr)
        }
    }

    private mutating func parseSetStatement() throws -> SetStatement {
        let l = current.line
        try consume(.kwSet)
        let target = try parseLValue()
        try consume(.kwTo)
        let value = try parseExpression()
        skipNewlines()
        return SetStatement(target: target, value: value, line: l)
    }

    private mutating func parseLValue() throws -> LValue {
        // set item at <expr> in <expr> to ...
        if matches(.kwItem) {
            advance()
            try consume(.kwAt)
            let index = try parseExpression()
            try consume(.kwIn)
            let list = try parseExpression()
            return .listItem(index: index, list: list)
        }

        // set "<key>" in <expr> to ...
        if case .textLiteral(let key) = current.kind {
            let keyExpr = Expression.text(key)
            advance()
            if matches(.kwIn) {
                advance()
                let map = try parseExpression()
                return .mapEntry(key: keyExpr, map: map)
            }
            throw parseError("Expected 'in' after key in set statement")
        }

        // set this->property or set variable
        let expr = try parsePrimaryExpression()
        if case .propertyAccess(let obj, let prop) = expr {
            return .property(obj, prop)
        }
        if case .identifier(let name) = expr {
            return .variable(name)
        }
        throw parseError("Invalid assignment target")
    }

    private mutating func parseReturnStatement() throws -> ReturnStatement {
        let l = current.line
        try consume(.kwReturn)
        if matches(.newline) || isAtEnd {
            skipNewlines()
            return ReturnStatement(value: nil, line: l)
        }
        let value = try parseExpression()
        skipNewlines()
        return ReturnStatement(value: value, line: l)
    }

    private mutating func parseIfStatement() throws -> IfStatement {
        let l = current.line
        try consume(.kwIf)
        let condition = try parseExpression()
        skipNewlines()
        let thenBody = try parseBody()
        var elseIfs:  [(Expression, [Statement])] = []
        var elseBody: [Statement]? = nil

        while matches(.kwElse) {
            advance()
            if matches(.kwIf) {
                advance()
                let c = try parseExpression()
                skipNewlines()
                let b = try parseBody()
                elseIfs.append((c, b))
            } else {
                skipNewlines()
                elseBody = try parseBody()
                break
            }
        }

        return IfStatement(condition: condition, thenBody: thenBody,
                           elseIfs: elseIfs, elseBody: elseBody, line: l)
    }

    private mutating func parseWhileStatement() throws -> WhileStatement {
        let l = current.line
        try consume(.kwWhile)
        let condition = try parseExpression()
        skipNewlines()
        let body = try parseBody()
        return WhileStatement(condition: condition, body: body, line: l)
    }

    private mutating func parseForStatement() throws -> Statement {
        let l = current.line
        try consume(.kwFor)
        if matches(.kwEach) {
            advance()
            let variable = try consumeIdentifier()
            try consume(.kwIn)
            let collection = try parseExpression()
            skipNewlines()
            let body = try parseBody()
            return .forEach(ForEachStatement(variable: variable, collection: collection, body: body, line: l))
        } else {
            let variable = try consumeIdentifier()
            try consume(.kwFrom)
            let from = try parseExpression()
            try consume(.kwTo)
            let to = try parseExpression()
            skipNewlines()
            let body = try parseBody()
            return .forRange(ForRangeStatement(variable: variable, from: from, to: to, body: body, line: l))
        }
    }

    private mutating func parseParallelStatement() throws -> ParallelStatement {
        let l = current.line
        try consume(.kwParallel)
        skipNewlines()
        try consume(.indent)
        var decls: [Declaration] = []
        while !matches(.dedent) && !isAtEnd {
            skipNewlines()
            decls.append(try parseDeclaration())
        }
        try consume(.dedent)
        return ParallelStatement(declarations: decls, line: l)
    }

    private mutating func parseTryCatchStatement() throws -> TryCatchStatement {
        let l = current.line
        try consume(.kwTry)
        skipNewlines()
        let body = try parseBody()
        var catches: [CatchClause] = []
        while matches(.kwCatch) {
            advance()
            var errorType: String? = nil
            var binding = "error"
            if let name = currentIdentifierOrTypeName(), name != "error" {
                errorType = name
                advance()
                if matches(.kwAs) {
                    advance()
                    binding = try consumeIdentifier()
                }
            } else {
                binding = try consumeIdentifier()
            }
            skipNewlines()
            let catchBody = try parseBody()
            catches.append(CatchClause(errorType: errorType, binding: binding, body: catchBody))
        }
        return TryCatchStatement(body: body, catches: catches, line: l)
    }

    private mutating func parseThrowStatement() throws -> ThrowStatement {
        let l = current.line
        try consume(.kwThrow)
        let name = try consumeIdentifier()
        var args: [(String, Expression)] = []
        if matches(.kwWith) {
            advance()
            let pName = try consumeIdentifier()
            let value = try parseExpression()
            args.append((pName, value))
            while matches(.kwAnd) {
                advance()
                let n = try consumeIdentifier()
                let v = try parseExpression()
                args.append((n, v))
            }
        }
        skipNewlines()
        return ThrowStatement(errorName: name, args: args, line: l)
    }

    private mutating func parsePrintStatement() throws -> PrintStatement {
        let l = current.line
        try consume(.kwPrint)
        let value = try parseExpression()
        var destination: PrintDestination = .standard
        var color: Expression? = nil
        var style: TextStyle? = nil
        if matches(.kwTo) {
            advance()
            // "to error output"
            try consume(.kwError)
            _ = try consumeIdentifier() // output
            destination = .error
        }
        if matches(.kwWith) {
            advance()
            while true {
                if matches(.kwColor) {
                    advance()
                    color = try parseExpression()
                } else if matches(.kwStyle) {
                    advance()
                    style = try parseStyleToken()
                }
                if matches(.kwAnd) { advance() } else { break }
            }
        }
        skipNewlines()
        return PrintStatement(value: value, destination: destination, color: color, style: style, line: l)
    }

    private mutating func parseStyleToken() throws -> TextStyle {
        switch current.kind {
        case .identifier(let s):
            advance()
            switch s {
            case "bold":      return .bold
            case "italic":    return .italic
            case "underline": return .underline
            case "dim":       return .dim
            default: throw parseError("Unknown style '\(s)'")
            }
        default: throw parseError("Expected style name")
        }
    }

    private mutating func parseSendStatement() throws -> SendStatement {
        let l = current.line
        try consume(.kwSend)
        let value = try parseExpression()
        try consume(.kwTo)
        let channel = try parseExpression()
        skipNewlines()
        return SendStatement(value: value, channel: channel, line: l)
    }

    private mutating func parseCloseStatement() throws -> CloseStatement {
        let l = current.line
        try consume(.kwClose)
        let channel = try parseExpression()
        skipNewlines()
        return CloseStatement(channel: channel, line: l)
    }

    private mutating func parseRunStatement() throws -> RunStatement {
        let l = current.line
        try consume(.kwRun)
        let name = try consumeIdentifier()
        var args: [(String?, Expression)] = []
        while !matches(.newline) && !isAtEnd {
            let preposition = isPreposition(current) ? { let s = tokenText(current); advance(); return s }() : nil
            let expr = try parseExpression()
            args.append((preposition, expr))
        }
        skipNewlines()
        return RunStatement(name: name, args: args, line: l)
    }

    private mutating func parseAddStatement() throws -> AddStatement {
        let l = current.line
        try consume(.kwAdd)
        let value = try parseExpression()
        try consume(.kwTo)
        let collection = try parseExpression()
        skipNewlines()
        return AddStatement(value: value, collection: collection, line: l)
    }

    private mutating func parseRemoveStatement() throws -> RemoveStatement {
        let l = current.line
        try consume(.kwRemove)
        let value = try parseExpression()
        try consume(.kwFrom)
        let collection = try parseExpression()
        skipNewlines()
        return RemoveStatement(value: value, collection: collection, line: l)
    }

    private mutating func parseWriteStatement() throws -> WriteStatement {
        let l = current.line
        try consume(.kwWrite)
        let content = try parseExpression()
        try consume(.kwTo)
        try consume(.kwFile)
        try consume(.kwAt)
        let path = try parseExpression()
        skipNewlines()
        return WriteStatement(content: content, path: path, line: l)
    }

    private mutating func parseAppendStatement() throws -> AppendStatement {
        let l = current.line
        try consume(.kwAppend)
        let content = try parseExpression()
        try consume(.kwTo)
        try consume(.kwFile)
        try consume(.kwAt)
        let path = try parseExpression()
        skipNewlines()
        return AppendStatement(content: content, path: path, line: l)
    }

    private mutating func parseCreateStatement() throws -> Statement {
        try consume(.kwCreate)
        try consume(.kwDirectory)
        try consume(.kwAt)
        let path = try parseExpression()
        skipNewlines()
        return .createDirectory(path)
    }

    private mutating func parseDeleteStatement() throws -> Statement {
        let l = current.line
        try consume(.kwDelete)
        if matches(.kwFile) {
            advance()
            try consume(.kwAt)
            let path = try parseExpression()
            skipNewlines()
            return .deleteFile(path)
        } else if matches(.kwDirectory) {
            advance()
            try consume(.kwAt)
            let path = try parseExpression()
            skipNewlines()
            return .deleteDirectory(path)
        }
        throw parseError("Expected 'file' or 'directory' after 'delete'")
    }

    private mutating func parseCopyStatement() throws -> Statement {
        try consume(.kwCopy)
        try consume(.kwFile)
        try consume(.kwFrom)
        let from = try parseExpression()
        try consume(.kwTo)
        let to = try parseExpression()
        skipNewlines()
        return .copyFile(from: from, to: to)
    }

    private mutating func parseMoveStatement() throws -> Statement {
        try consume(.kwMove)
        try consume(.kwFile)
        try consume(.kwFrom)
        let from = try parseExpression()
        try consume(.kwTo)
        let to = try parseExpression()
        skipNewlines()
        return .moveFile(from: from, to: to)
    }

    private mutating func parseClearStatement() throws -> Statement {
        try consume(.kwClear)
        _ = try consumeIdentifier() // "terminal"
        skipNewlines()
        return .clearTerminal
    }

    private mutating func parseExitStatement() throws -> ExitStatement {
        let l = current.line
        try consume(.kwExit)
        try consume(.kwWith)
        _ = try consumeIdentifier() // "code"
        let code = try parseExpression()
        skipNewlines()
        return ExitStatement(code: code, line: l)
    }

    // MARK: — Expressions (scaffold)

    private mutating func parseExpression() throws -> Expression {
        return try parseOr()
    }

    private mutating func parseOr() throws -> Expression {
        var left = try parseAnd()
        while matches(.kwOr) {
            advance()
            let right = try parseAnd()
            left = .binary(left, .or, right)
        }
        return left
    }

    private mutating func parseAnd() throws -> Expression {
        var left = try parseEquality()
        while matches(.kwAnd) {
            advance()
            let right = try parseEquality()
            left = .binary(left, .and, right)
        }
        return left
    }

    private mutating func parseEquality() throws -> Expression {
        var left = try parseComparison()
        while true {
            if matches(.kwIs) {
                advance()
                if matches(.kwNot) {
                    advance()
                    if matches(.kwIn) {
                        advance()
                        let right = try parseComparison()
                        left = .unary(.not, .binary(left, .inCollection, right))
                    } else {
                        let right = try parseComparison()
                        left = .binary(left, .notEqual, right)
                    }
                } else if matches(.kwIn) {
                    advance()
                    let right = try parseComparison()
                    left = .binary(left, .inCollection, right)
                } else {
                    let right = try parseComparison()
                    left = .binary(left, .equal, right)
                }
            } else {
                break
            }
        }
        return left
    }

    private mutating func parseComparison() throws -> Expression {
        var left = try parseAdditive()
        while true {
            if matches(.greater)      { advance(); left = .binary(left, .greater,      try parseAdditive()) }
            else if matches(.less)    { advance(); left = .binary(left, .less,         try parseAdditive()) }
            else if matches(.greaterEqual) { advance(); left = .binary(left, .greaterEqual, try parseAdditive()) }
            else if matches(.lessEqual)    { advance(); left = .binary(left, .lessEqual,    try parseAdditive()) }
            else { break }
        }
        return left
    }

    private mutating func parseAdditive() throws -> Expression {
        var left = try parseMultiplicative()
        while true {
            if matches(.plus)  { advance(); left = .binary(left, .add,      try parseMultiplicative()) }
            else if matches(.minus) { advance(); left = .binary(left, .subtract, try parseMultiplicative()) }
            else { break }
        }
        return left
    }

    private mutating func parseMultiplicative() throws -> Expression {
        var left = try parseUnary()
        while true {
            if matches(.star)  { advance(); left = .binary(left, .multiply, try parseUnary()) }
            else if matches(.slash) { advance(); left = .binary(left, .divide,   try parseUnary()) }
            else { break }
        }
        return left
    }

    private mutating func parseUnary() throws -> Expression {
        if matches(.kwNot) { advance(); return .unary(.not, try parseUnary()) }
        if matches(.minus) { advance(); return .unary(.negate, try parseUnary()) }
        return try parsePostfix()
    }

    private mutating func parsePostfix() throws -> Expression {
        var expr = try parsePrimaryExpression()
        while matches(.arrow) {
            advance()
            let prop = try consumeIdentifier()
            if matches(.openParen) {
                advance()
                var args: [(String?, Expression)] = []
                while !matches(.closeParen) {
                    let argExpr = try parseExpression()
                    args.append((nil, argExpr))
                    if matches(.comma) { advance() }
                }
                try consume(.closeParen)
                expr = .methodCall(expr, prop, args)
            } else {
                expr = .propertyAccess(expr, prop)
            }
        }
        return expr
    }

    private mutating func parsePrimaryExpression() throws -> Expression {
        switch current.kind {
        case .textLiteral(let s):   advance(); return .text(s)
        case .numberLiteral(let n): advance(); return .number(n)
        case .decimalLiteral(let d):advance(); return .decimal(d)
        case .boolLiteral(let b):   advance(); return .bool(b)
        case .nothing:              advance(); return .nothing
        case .kwThis:               advance(); return .this
        case .openParen:
            advance()
            let expr = try parseExpression()
            try consume(.closeParen)
            return expr
        case .kwIf:
            return try parseInlineIf()
        case .kwAwait:
            advance()
            let inner = try parseExpression()
            return .awaitExpr(inner)
        case .identifier(let name):
            advance()
            return .identifier(name)
        default:
            // Standard library expressions are parsed here
            return try parseStdlibExpression()
        }
    }

    private mutating func parseInlineIf() throws -> Expression {
        try consume(.kwIf)
        let cond = try parseExpression()
        try consume(.kwThen)
        let then = try parseExpression()
        try consume(.kwElse)
        let els = try parseExpression()
        return .inlineIf(condition: cond, then: then, else: els)
    }

    private mutating func parseStdlibExpression() throws -> Expression {
        // Scaffold — stdlib expression parsing dispatches here
        // Full implementation parses all StdlibExpr cases
        throw parseError("Unexpected token in expression: \(current.description)")
    }

    // MARK: — Helpers

    private var current: Token { tokens[min(pos, tokens.count - 1)] }
    private var isAtEnd: Bool {
        if case .endOfFile = current.kind { return true }
        return pos >= tokens.count
    }

    @discardableResult
    private mutating func advance() -> Token {
        let t = tokens[pos]
        pos += 1
        return t
    }

    private func matches(_ kind: TokenKind) -> Bool { current.kind == kind }

    @discardableResult
    private mutating func consume(_ kind: TokenKind) throws -> Token {
        guard current.kind == kind else {
            throw parseError("Expected \(kind), got \(current.description)")
        }
        return advance()
    }

    private mutating func consumeIdentifier() throws -> String {
        if let name = currentIdentifierOrTypeName() {
            advance()
            return name
        }
        throw parseError("Expected identifier, got \(current.description)")
    }

    private func currentIdentifierOrTypeName() -> String? {
        switch current.kind {
        case .identifier(let s): return s
        // Allow type-like keywords as identifiers in some positions
        default: return nil
        }
    }

    private mutating func skipNewlines() {
        while matches(.newline) { advance() }
    }

    private func isPreposition(_ t: Token) -> Bool {
        switch t.kind {
        case .kwTo, .kwFrom, .kwBy, .kwWith, .kwIn, .kwAt, .kwOf,
             .kwOn, .kwInto, .kwAnd: return true
        default: return false
        }
    }

    private func tokenText(_ t: Token) -> String {
        switch t.kind {
        case .kwTo:   return "to"
        case .kwFrom: return "from"
        case .kwBy:   return "by"
        case .kwWith: return "with"
        case .kwIn:   return "in"
        case .kwAt:   return "at"
        case .kwOf:   return "of"
        case .kwAnd:  return "and"
        default:      return ""
        }
    }

    private func parseError(_ message: String) -> ParseError {
        ParseError(message: message, line: current.line, column: current.column)
    }
}

// Temporary — remove when full keyword set added to TokenKind
extension TokenKind {
    static var kwOn: TokenKind   { .identifier("on") }
    static var kwInto: TokenKind { .identifier("into") }
    static var kwList: TokenKind { .identifier("list") }
    static var kwMap:  TokenKind { .identifier("map") }
    static var kwError: TokenKind { .kwError }
}
