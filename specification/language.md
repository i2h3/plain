# PLAIN Language Specification

Version 0.1 — Draft

---

## 1. Overview

PLAIN (Practical Language for Applications and Intelligence) is a statically typed, compiled, general-purpose programming language. Every statement follows one grammar rule:

> **verb** direct-object **preposition** value …

Source files use the `.plain` extension. All source files in the same build target form one shared namespace — no import declarations are needed.

---

## 2. Lexical structure

### 2.1 Indentation

Indentation is enforced by the compiler.

- One level equals exactly 4 spaces.
- Tabs are a compile error.
- The body of every block-opening construct must be indented one level deeper than the construct itself.
- The closing `end` must align with the opening keyword.

### 2.2 Comments

**Line comment** — `note` followed by any text; the rest of the line is ignored by the compiler.

```plain
note This is a line comment
let x be 1    note inline comment after a statement
```

**Block comment** — `note` on its own line, closed by `end`.

```plain
note
    This explanation spans
    multiple lines.
end
```

**Documentation comment** — `describe` (line or block form) placed immediately before a declaration. Used by documentation tools.

```plain
describe Returns a greeting for the given name.
function greet name as text returns text
    return "Hello, " + name + "!"
end

describe
    Represents a registered user.
    name — the user's display name.
    age  — the user's age in years.
end
class user
    property name as text
    property age  as number
end
```

`note` and `describe` are reserved keywords and may not be used as identifiers.

### 2.3 Keywords

```
let var set be as to from by with and or not of in at
if else while for each from to end return
function task returns
class feature extends is init parent this
error throw try catch
parallel run send close channel shared await
print input add remove
nothing true false
program app start
note describe
```

### 2.4 Identifiers

Identifiers begin with a letter and contain letters, digits, and underscores. PLAIN identifiers are case-sensitive. By convention, type names and class names use lower case. Multi-word identifiers use camel case.

### 2.5 Literals

**Text** — UTF-8, delimited by double quotes. Escape sequences: `\"`, `\\`, `\n`, `\t`.
```plain
"Hello, World!"
"Line one\nLine two"
```

**Number** — 64-bit signed integer.
```plain
42
-7
```

**Decimal** — 64-bit IEEE 754 double.
```plain
3.14
-0.5
```

**Bool**
```plain
true
false
```

**Nothing**
```plain
nothing
```

**List** — comma-separated values, terminated by end of line. Explicit type annotation required when the list is empty.
```plain
"Red", "Green", "Blue"
1, 2, 3
```

**Dictionary** — comma-separated key-colon-value pairs, terminated by end of line.
```plain
"Iva": 30, "Max": 25
```

---

## 3. Types

### 3.1 Built-in types

| Type | Description |
|---|---|
| `text` | UTF-8 string |
| `number` | 64-bit signed integer |
| `decimal` | 64-bit IEEE 754 double |
| `bool` | `true` or `false` |
| `nothing` | Absence of a value |
| `list of T` | Ordered collection |
| `map of K to V` | Key-value collection |
| `channel of T` | Typed concurrent pipe |
| `json` | Untyped JSON value |
| `path` | File system path |
| `moment` | Point in time |
| `response` | HTTP response |

### 3.2 Union with nothing (optional)

A value that may be absent is declared with `or nothing`:

```plain
let found as text or nothing
```

### 3.3 Type inference

The compiler infers the type of a declaration when it is unambiguous from the assigned value:

```plain
let name be "Iva"        note inferred: text
let age  be 30           note inferred: number
let price be 19.99       note inferred: decimal
let active be true       note inferred: bool
```

---

## 4. Variable declarations

### 4.1 Immutable

```plain
let name be "Iva"
let name as text be "Iva"
```

Immutable variables may not appear on the left side of a `set` statement after initialisation.

### 4.2 Mutable

```plain
var counter be 0
var score as decimal be 0.0
var buffer as list of text
```

### 4.3 Shared mutable (concurrent)

Shared variables are accessible from multiple tasks. The compiler generates automatic synchronisation.

```plain
shared var requestCount be 0
```

---

## 5. Assignment

```plain
set counter to counter + 1
set name    to "New Name"
set department of this to department
set item at 1 in colours to "Teal"
set "Iva" in ages to 31
```

`set` followed by a target and `to` followed by a value. The target may be a variable, a property access, a list item, or a dictionary entry.

---

## 6. Operators

### 6.1 Arithmetic

| Operator | Meaning |
|---|---|
| `+` | Addition or text concatenation |
| `-` | Subtraction |
| `*` | Multiplication |
| `/` | Division |

### 6.2 Comparison

| Operator | Meaning |
|---|---|
| `is` | Equality |
| `is not` | Inequality |
| `>` | Greater than |
| `<` | Less than |
| `>=` | Greater than or equal |
| `<=` | Less than or equal |

### 6.3 Logical

```plain
and   or   not
```

### 6.4 Property and method access

```plain
name of iva
introduce of iva
describe of emp
```

`of` accesses a property or calls a method on an object.

### 6.5 Inline conditional expression

```plain
if condition then valueA else valueB
```

Used inside expressions where a conditional value is needed.

---

## 7. Functions

### 7.1 Declaration

```plain
note No parameters
function greet returns text
    return "Hello, World!"
end

note One parameter — direct object, no preposition required
function greet name as text returns text
    return "Hello, " + name + "!"
end

note Multiple parameters — each after the first requires a preposition
function connect to host as text on port as number returns bool
    note ...
end

function replace old as text with new as text in source as text returns text
    note ...
end

note No return value
function logStatus
    print "Running"
end
```

### 7.2 Calling

```plain
let greeting be greet "Iva"
let ok       be connect to "example.com" on port 443
let result   be replace "hello" with "world" in myText
logStatus
```

At the call site, prepositions match the declaration. Parameter names are optional for readability but must match the declaration when included.

### 7.3 Return

```plain
return value
return
```

A function with no declared return type returns implicitly at the end of its body.

---

## 8. Task functions (asynchronous)

```plain
task function fetch from url as text returns text
    return await httpGet url
end

let content be await fetch from "https://example.com"
```

Task functions run asynchronously. Calling a task function requires `await`. A task function may only be called with `await` from within another task function or a `parallel` block.

---

## 9. Control flow

### 9.1 Conditional

```plain
if condition
    note ...
else if otherCondition
    note ...
else
    note ...
end
```

### 9.2 While loop

```plain
while condition
    note ...
end
```

### 9.3 Range loop

```plain
for step from 1 to 5
    print step
end
```

The range is inclusive at both ends.

### 9.4 Collection loop

```plain
for each colour in colours
    print colour
end
```

### 9.5 Parallel block

```plain
parallel
    let a be await taskA
    let b be await taskB
end
```

All declarations inside a `parallel` block run concurrently. Execution continues below only when all have completed. All declared variables are guaranteed available after the block.

---

## 10. Classes

### 10.1 Declaration

```plain
class person
    property name as text
    property age  as number

    init with name as text and age as number
        set name of this to name
        set age  of this to age
    end

    function introduce returns text
        return "I am " + name of this + ", " + age of this + " years old."
    end
end
```

All classes are reference types. There are no value types (structs).

### 10.2 Construction

```plain
let iva be person with name "Iva" and age 30
```

When all properties have a matching `init` parameter, the compiler synthesises the constructor. A custom `init` block may be provided for additional logic.

### 10.3 Inheritance

```plain
class employee extends person
    property department as text

    init with name as text and age as number and department as text
        parent with name name and age age
        set department of this to department
    end
end
```

`parent` calls the parent class initialiser.

### 10.4 Features

A `feature` declares a set of requirements a class must satisfy:

```plain
feature describable
    function describe returns text
end
```

A class declares conformance with `is`:

```plain
class employee extends person is describable
    function describe returns text
        return introduce of this + " — " + department of this
    end
end
```

Multiple features:

```plain
class employee extends person is describable and serialisable
```

Runtime conformance check:

```plain
if emp is describable
    print describe of emp
end
```

### 10.5 The codable feature

Classes declaring `is codable` gain automatic JSON encode and decode. All properties must themselves be codable types.

```plain
class user is codable
    property name as text
    property age  as number
end

let u       be user from json body
let encoded be json of u
```

Custom key mapping:

```plain
class user is codable
    property name as text   mapping "full_name"
    property age  as number mapping "user_age"
end
```

Custom decode and encode:

```plain
class user is codable
    property name as text
    property age  as number

    decode from data as json
        set name of this to text of "full_name" in data
        set age  of this to number of "years" in data
    end

    encode returns json
        let data be json object
        set "full_name" in data to name of this
        set "years"     in data to age of this
        return data
    end
end
```

---

## 11. Error handling

### 11.1 Declaring error types

```plain
error networkFailure with code as number and message as text
error parseFailure with message as text
```

### 11.2 Throwing

```plain
throw networkFailure with code 404 and message "Not found"
```

### 11.3 Catching

```plain
try
    let result be riskyOperation
catch networkFailure as error
    print "Network error " + text from code of error + ": " + message of error
catch error
    print "Unexpected error: " + message of error
end
```

A bare `catch error` catches any error not matched by a preceding specific catch clause.

---

## 12. Concurrency

### 12.1 Tasks

A `task function` is an asynchronous unit of work. It runs on a background thread. File and network operations called from within a task block the task's thread, not the main thread.

### 12.2 Channels

```plain
let pipe as channel of number

task function produce into out as send channel of number
    for step from 1 to 10
        send step to out
    end
    close out
end

task function consume from in as receive channel of number
    for each value in in
        print "Received: " + value
    end
end

parallel
    run produce into pipe
    run consume from pipe
end
```

Channels are directional. `send channel of T` permits only sending. `receive channel of T` permits only receiving. The compiler enforces this.

### 12.3 Shared state

```plain
shared var count be 0

task function increment
    set count to count + 1
end
```

The compiler wraps all accesses to `shared` variables in automatic synchronisation.

---

## 13. Modules

All `.plain` source files in the same build target form one shared namespace. No import declarations are needed. Name conflicts between files are a compile error.

---

## 14. Collections — built-in operations

```plain
note List mutation
add "Purple" to colours
remove "Red" from colours
set item at 1 in colours to "Teal"

note List access
let first be item at 0 in colours

note Dictionary mutation
set "Iva" in ages to 31
add "Bob" with value 26 to ages
remove "Max" from ages

note Dictionary access
let age be "Iva" in ages

note Membership
if "hello" is in myText
if ages has "Iva"
```

---

## 15. Grammar summary

| Construct | Pattern |
|---|---|
| Declare immutable | `let name [as type] be value` |
| Declare mutable | `var name [as type] be value` |
| Assign | `set target to value` |
| Call function | `name [value] [prep value]*` |
| Call method | `method of object [value] [prep value]*` |
| Read property | `property of object` |
| Construct object | `TypeName with property value [and property value]*` |
| Add to list | `add value to list` |
| Remove from list | `remove value from list` |
| Read list item | `item at index in list` |
| Write list item | `set item at index in list to value` |
| Read map entry | `key in map` |
| Write map entry | `set key in map to value` |
| Throw error | `throw errorType with property value [and property value]*` |
| Send to channel | `send value to channel` |
| Run task | `run taskName [prep value]*` |
| Await task | `let result be await taskName [prep value]*` |
