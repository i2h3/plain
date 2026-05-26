// Lexer.swift — PLAIN source → [Token]

struct LexerError: Error {
    let message: String
    let line:    Int
    let column:  Int
}

struct Lexer {

    private let source:   [Character]
    private var pos:      Int = 0
    private var line:     Int = 1
    private var column:   Int = 1
    private var indentStack: [Int] = [0]
    private var tokens:   [Token] = []
    private var atLineStart: Bool = true

    private static let keywords: [String: TokenKind] = [
        "let": .kwLet, "var": .kwVar, "set": .kwSet, "be": .kwBe,
        "as": .kwAs, "to": .kwTo, "from": .kwFrom, "by": .kwBy,
        "with": .kwWith, "and": .kwAnd, "or": .kwOr, "not": .kwNot,
        "of": .kwOf, "in": .kwIn, "at": .kwAt, "mapping": .kwMapping,
        "if": .kwIf, "else": .kwElse, "while": .kwWhile,
        "for": .kwFor, "each": .kwEach, "end": .kwEnd,
        "return": .kwReturn, "then": .kwThen,
        "function": .kwFunction, "task": .kwTask, "returns": .kwReturns,
        "class": .kwClass, "feature": .kwFeature, "extends": .kwExtends,
        "is": .kwIs, "init": .kwInit, "parent": .kwParent, "this": .kwThis,
        "property": .kwProperty, "shared": .kwShared,
        "codable": .kwCodable, "decode": .kwDecode, "encode": .kwEncode,
        "error": .kwError, "throw": .kwThrow, "try": .kwTry, "catch": .kwCatch,
        "parallel": .kwParallel, "run": .kwRun, "send": .kwSend,
        "close": .kwClose, "channel": .kwChannel, "await": .kwAwait,
        "print": .kwPrint, "input": .kwInput, "add": .kwAdd,
        "remove": .kwRemove, "program": .kwProgram, "app": .kwApp,
        "start": .kwStart,
        "nothing": .nothing, "true": .boolLiteral(true), "false": .boolLiteral(false),
        "uppercase": .kwUppercase, "lowercase": .kwLowercase,
        "trim": .kwTrim, "reverse": .kwReverse, "replacement": .kwReplacement,
        "length": .kwLength, "positions": .kwPositions,
        "substring": .kwSubstring, "character": .kwCharacter,
        "parts": .kwParts, "words": .kwWords, "lines": .kwLines,
        "join": .kwJoin, "padding": .kwPadding, "left": .kwLeft, "right": .kwRight,
        "round": .kwRound, "floor": .kwFloor, "ceiling": .kwCeiling,
        "absolute": .kwAbsolute, "square": .kwSquare, "root": .kwRoot,
        "power": .kwPower, "remainder": .kwRemainder,
        "minimum": .kwMinimum, "maximum": .kwMaximum,
        "sum": .kwSum, "average": .kwAverage, "count": .kwCount,
        "sort": .kwSort, "filter": .kwFilter,
        "first": .kwFirst, "last": .kwLast, "any": .kwAny, "all": .kwAll,
        "unique": .kwUnique, "combination": .kwCombination,
        "shuffle": .kwShuffle, "random": .kwRandom,
        "moment": .kwMoment, "current": .kwCurrent,
        "year": .kwYear, "month": .kwMonth, "day": .kwDay,
        "hour": .kwHour, "minute": .kwMinute, "second": .kwSecond,
        "millisecond": .kwMillisecond, "before": .kwBefore,
        "after": .kwAfter, "between": .kwBetween,
        "days": .kwDays, "hours": .kwHours, "minutes": .kwMinutes,
        "seconds": .kwSeconds, "milliseconds": .kwMilliseconds,
        "weeks": .kwWeeks, "months": .kwMonths, "years": .kwYears,
        "same": .kwSame,
        "path": .kwPath, "name": .kwName, "extension": .kwExtension,
        "full": .kwFull, "home": .kwHome, "temporary": .kwTemporary,
        "directory": .kwDirectory, "contents": .kwContents,
        "file": .kwFile, "write": .kwWrite, "append": .kwAppend,
        "size": .kwSize, "modification": .kwModification,
        "exists": .kwExists, "copy": .kwCopy, "move": .kwMove,
        "create": .kwCreate, "delete": .kwDelete,
        "response": .kwResponse, "status": .kwStatus,
        "body": .kwBody, "header": .kwHeader,
        "get": .kwGet, "post": .kwPost, "put": .kwPut, "patch": .kwPatch,
        "json": .kwJson, "parse": .kwParse, "object": .kwObject, "array": .kwArray,
        "text": .kwText, "number": .kwNumber, "decimal": .kwDecimal,
        "bool": .kwBool,
        "terminal": .kwTerminal, "clear": .kwClear,
        "width": .kwWidth, "height": .kwHeight,
        "color": .kwColor, "style": .kwStyle,
        "environment": .kwEnvironment, "arguments": .kwArguments,
        "operating": .kwOperating, "system": .kwSystem, "exit": .kwExit,
        "item": .kwItem, "value": .kwValue, "key": .kwKey,
        "entry": .kwEntry, "presence": .kwPresence,
        "prefix": .kwPrefix, "suffix": .kwSuffix,
        "parent": .kwParent,
    ]

    init(source: String) {
        self.source = Array(source)
    }

    mutating func tokenise() throws -> [Token] {
        while !isAtEnd {
            try scanToken()
        }
        emitDedentsToBaseLevel()
        emit(.endOfFile)
        return tokens
    }

    // MARK: — Core scan loop

    private mutating func scanToken() throws {
        if atLineStart {
            try handleIndentation()
            atLineStart = false
        }

        skipWhitespace()

        guard !isAtEnd else { return }

        let c = advance()

        switch c {
        case "\n":
            emit(.newline)
            line += 1
            column = 1
            atLineStart = true

        case "/":
            if peek() == "/" {
                skipLineComment()
            } else {
                emit(.slash)
            }

        case "\"":
            try scanTextLiteral()

        case "-":
            if peek() == ">" {
                advance()
                emit(.arrow)
            } else if let d = peek(), d.isNumber {
                try scanNumber(negative: true)
            } else {
                emit(.minus)
            }

        case "+": emit(.plus)
        case "*": emit(.star)
        case "(": emit(.openParen)
        case ")": emit(.closeParen)
        case ":": emit(.colon)
        case ",": emit(.comma)

        case ">":
            if peek() == "=" { advance(); emit(.greaterEqual) }
            else { emit(.greater) }

        case "<":
            if peek() == "=" { advance(); emit(.lessEqual) }
            else { emit(.less) }

        default:
            if c.isNumber {
                try scanNumber(firstChar: c, negative: false)
            } else if c.isLetter || c == "_" {
                scanIdentifierOrKeyword(firstChar: c)
            } else {
                throw LexerError(
                    message: "Unexpected character '\(c)'",
                    line: line, column: column
                )
            }
        }
    }

    // MARK: — Indentation

    private mutating func handleIndentation() throws {
        var spaces = 0
        while !isAtEnd && peek() == " " {
            advance()
            spaces += 1
        }

        if peek() == "\n" || isAtEnd { return }

        let current = indentStack.last ?? 0

        if spaces > current {
            if spaces - current != 4 {
                throw LexerError(
                    message: "Indentation must be exactly 4 spaces per level, found \(spaces - current)",
                    line: line, column: column
                )
            }
            indentStack.append(spaces)
            emit(.indent)
        } else if spaces < current {
            while let top = indentStack.last, top > spaces {
                indentStack.removeLast()
                emit(.dedent)
            }
            if indentStack.last != spaces {
                throw LexerError(
                    message: "Dedent does not match any outer indentation level",
                    line: line, column: column
                )
            }
        }
    }

    private mutating func emitDedentsToBaseLevel() {
        while let top = indentStack.last, top > 0 {
            indentStack.removeLast()
            emit(.dedent)
        }
    }

    // MARK: — Literals

    private mutating func scanTextLiteral() throws {
        var result = ""
        while !isAtEnd && peek() != "\"" {
            let c = advance()
            if c == "\\" {
                guard !isAtEnd else {
                    throw LexerError(message: "Unterminated escape sequence", line: line, column: column)
                }
                switch advance() {
                case "n":  result.append("\n")
                case "t":  result.append("\t")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case let e:
                    throw LexerError(message: "Unknown escape sequence '\\\\\\(e)'", line: line, column: column)
                }
            } else {
                result.append(c)
            }
        }
        guard !isAtEnd else {
            throw LexerError(message: "Unterminated text literal", line: line, column: column)
        }
        advance() // closing "
        emit(.textLiteral(result))
    }

    private mutating func scanNumber(firstChar: Character? = nil, negative: Bool) throws {
        var raw = negative ? "-" : ""
        if let c = firstChar { raw.append(c) }
        var isDecimal = false

        while !isAtEnd, let c = peek(), c.isNumber || (c == "." && !isDecimal) {
            if c == "." { isDecimal = true }
            raw.append(advance())
        }

        if isDecimal {
            guard let d = Double(raw) else {
                throw LexerError(message: "Invalid decimal literal '\(raw)'", line: line, column: column)
            }
            emit(.decimalLiteral(d))
        } else {
            guard let n = Int(raw) else {
                throw LexerError(message: "Invalid number literal '\(raw)'", line: line, column: column)
            }
            emit(.numberLiteral(n))
        }
    }

    private mutating func scanIdentifierOrKeyword(firstChar: Character) {
        var raw = String(firstChar)
        while !isAtEnd, let c = peek(), c.isLetter || c.isNumber || c == "_" {
            raw.append(advance())
        }
        let kind = Lexer.keywords[raw] ?? .identifier(raw)
        emit(kind)
    }

    // MARK: — Helpers

    private mutating func skipWhitespace() {
        while !isAtEnd, let c = peek(), c == " " || c == "\r" {
            advance()
        }
    }

    private mutating func skipLineComment() {
        while !isAtEnd && peek() != "\n" {
            advance()
        }
    }

    @discardableResult
    private mutating func advance() -> Character {
        let c = source[pos]
        pos += 1
        column += 1
        return c
    }

    private func peek() -> Character? {
        guard pos < source.count else { return nil }
        return source[pos]
    }

    private var isAtEnd: Bool { pos >= source.count }

    private mutating func emit(_ kind: TokenKind) {
        tokens.append(Token(kind: kind, line: line, column: column))
    }
}
