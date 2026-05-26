// Token.swift — PLAIN lexer token definitions

enum TokenKind: Equatable {

    // Literals
    case textLiteral(String)
    case numberLiteral(Int)
    case decimalLiteral(Double)
    case boolLiteral(Bool)
    case nothing

    // Identifier
    case identifier(String)

    // Keywords — declarations
    case kwLet, kwVar, kwSet, kwBe, kwAs, kwTo, kwFrom, kwBy
    case kwWith, kwAnd, kwOr, kwNot, kwOf, kwIn, kwAt, kwMapping

    // Keywords — control flow
    case kwIf, kwElse, kwWhile, kwFor, kwEach, kwEnd, kwReturn, kwThen

    // Keywords — functions
    case kwFunction, kwTask, kwReturns

    // Keywords — types and classes
    case kwClass, kwFeature, kwExtends, kwIs, kwInit, kwParent, kwThis
    case kwProperty, kwShared, kwCodable, kwDecode, kwEncode

    // Keywords — errors
    case kwError, kwThrow, kwTry, kwCatch

    // Keywords — concurrency
    case kwParallel, kwRun, kwSend, kwClose, kwChannel, kwAwait

    // Keywords — I/O and collections
    case kwPrint, kwInput, kwAdd, kwRemove, kwProgram, kwApp, kwStart

    // Keywords — standard library nouns
    case kwUppercase, kwLowercase, kwTrim, kwReverse, kwReplacement
    case kwLength, kwPositions, kwSubstring, kwCharacter, kwParts
    case kwWords, kwLines, kwJoin, kwPadding, kwLeft, kwRight
    case kwRound, kwFloor, kwCeiling, kwAbsolute, kwSquare, kwRoot
    case kwPower, kwRemainder, kwMinimum, kwMaximum, kwSum, kwAverage
    case kwCount, kwSort, kwFilter, kwFirst, kwLast, kwAny, kwAll
    case kwUnique, kwCombination, kwShuffle, kwRandom
    case kwMoment, kwCurrent, kwYear, kwMonth, kwDay, kwHour
    case kwMinute, kwSecond, kwMillisecond, kwBefore, kwAfter, kwBetween
    case kwDays, kwHours, kwMinutes, kwSeconds, kwMilliseconds
    case kwWeeks, kwMonths, kwYears, kwSame
    case kwPath, kwName, kwExtension, kwParent, kwFull, kwHome
    case kwTemporary, kwDirectory, kwContents, kwFile, kwWrite
    case kwAppend, kwSize, kwModification, kwDate, kwExists
    case kwCopy, kwMove, kwCreate, kwDelete
    case kwResponse, kwStatus, kwBody, kwHeader, kwGet, kwPost
    case kwPut, kwPatch, kwJson, kwParse, kwObject, kwArray
    case kwText, kwNumber, kwDecimal, kwBool
    case kwTerminal, kwClear, kwWidth, kwHeight, kwColor, kwStyle
    case kwEnvironment, kwArguments, kwOperating, kwSystem, kwExit
    case kwItem, kwValue, kwKey, kwEntry, kwPresence, kwPrefix, kwSuffix

    // Punctuation and operators
    case arrow          // ->
    case colon          // :
    case comma          // ,
    case openParen      // (
    case closeParen     // )
    case plus           // +
    case minus          // -
    case star           // *
    case slash          // /
    case greater        // >
    case less           // <
    case greaterEqual   // >=
    case lessEqual      // <=

    // Structure
    case newline
    case indent
    case dedent
    case endOfFile
}

struct Token {
    let kind:   TokenKind
    let line:   Int
    let column: Int

    var description: String {
        switch kind {
        case .identifier(let s):      return "identifier(\(s))"
        case .textLiteral(let s):     return "text(\"\(s)\")"
        case .numberLiteral(let n):   return "number(\(n))"
        case .decimalLiteral(let d):  return "decimal(\(d))"
        case .boolLiteral(let b):     return "bool(\(b))"
        default:                      return "\(kind)"
        }
    }
}
