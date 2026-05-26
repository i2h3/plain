# Getting started with PLAIN

This guide walks through installing PLAIN, writing a first program, and understanding the core ideas.

---

## Installation

### Prerequisites

- A C compiler (GCC or Clang)
- Swift 5.9 or later (for the transpiler)

### Build the transpiler

```sh
git clone https://github.com/plain-lang/plain-lang
cd plain-lang/transpiler
swift build -c release
cp .build/release/plain /usr/local/bin/plain
```

### Verify

```sh
plain --version
```

---

## Hello, World

Create a file named `hello.plain`:

```plain
print "Hello, World!"
```

Run it:

```sh
plain run hello.plain
```

The transpiler compiles the file to C, compiles the C with the system C compiler, and runs the result.

---

## Core ideas

### One grammar rule

Every statement in PLAIN follows the same pattern:

```
verb   subject   preposition   value
set    counter   to            counter + 1
add    "Red"     to            colours
print  "Hello"
```

### Declarations

```plain
let name be "Iva"               // immutable, type inferred
let name as text be "Iva"       // immutable, explicit type
var counter be 0                // mutable
var buffer as list of text      // mutable, no initial value
```

### Assignment

```plain
set counter to counter + 1
set name    to "New Name"
```

### Functions

```plain
function greet name as text returns text
    return "Hello, " + name + "!"
end

print greet "World"
```

### Classes

```plain
class person
    property name as text
    property age  as number

    init with name as text and age as number
        set name of this to name
        set age  of this to age
    end

    function introduce returns text
        return "I am " + name of this + "."
    end
end

let iva be person with name "Iva" and age 30
print introduce of iva
```

### Control flow

```plain
if age >= 18
    print "Adult"
else
    print "Minor"
end

for step from 1 to 5
    print step
end

let colours as list of text be "Red", "Green", "Blue"
for each colour in colours
    print colour
end
```

### Error handling

```plain
error fileNotFound with path as text

try
    let content be contents of file at p
catch fileNotFound as error
    print "Not found: " + path of error
catch error
    print "Unexpected: " + message of error
end
```

### Concurrency

File and network operations are synchronous — they block the calling thread. Wrap them in a `task function` to run them concurrently without blocking the main thread:

```plain
task function loadData returns text
    let response be response of get from "https://api.example.com/data"
    return body of response
end

task function main
    parallel
        let dataA be await loadData
        let dataB be await loadData
    end
    print dataA
    print dataB
end
```

---

## Next steps

- Work through the [tutorial](../tutorial/01-hello-world.md) for a guided learning path
- Read the [language specification](../specification/language.md) for the complete reference
- Browse the [examples](../examples/) for realistic programs
