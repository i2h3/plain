# PLAIN — Design Decisions

This document records the reasoning behind the key design choices in PLAIN. It exists so that future contributors and AI assistants working with the codebase understand not just *what* was decided but *why*, and can apply the same reasoning to new situations.

---

## Language philosophy

### Readability over writability

PLAIN is designed for the AI age: AI agents write code, humans review it. This inverts the traditional trade-off. Brevity for the writer matters less than clarity for the reader. Every syntax decision is evaluated against the question: *can a non-programmer read this and understand what it does?*

### One grammar rule

Every statement follows the pattern `verb subject preposition value`. This was chosen over mixed styles (some noun-form, some verb-form, some method-chain) because consistency is the single most important property for learnability and AI generation. When in doubt about how to express something new, the answer is always: find the noun-form that fits this pattern.

### Natural English, globally

Keywords are English words but not idioms or Americanisms. The language is not tied to any cultural context. Abbreviations are avoided (`function` not `func`, `returns` not `->` for return types).

---

## Syntax decisions

### `be` for declarations, `set … to …` for assignment

`let name be "Iva"` was chosen over `let name = "Iva"` because `=` is a cryptic symbol with no natural reading. `be` reads as English: *let name be Iva*. The distinction between declaration (`be`) and mutation (`set … to`) is intentional — they are different operations with different constraints, and the syntax reflects that.

### `as` for type annotation

`name as text` reads naturally as *name, as a text value*. The colon (`:`) was rejected as it carries no natural English meaning.

### `of` for member access

Dot notation (`.`) and `->` were both considered and rejected. Dot is visually ambiguous with decimal points and sentence punctuation. `->` is distinctive but is still a cryptic symbol, inconsistent with the keyword-first philosophy. `of` was chosen because it already appears throughout PLAIN (`body of response`, `sort of employees by name`, `length of myText`) and requires no new syntax. `name of iva` reads as natural English and is immediately understood by non-programmers. The reversed order (property before object) is consistent with the noun-form pattern used by all standard library operations.

### `note` for comments, `describe` for documentation comments

`//` was rejected for the same reason as `=` and `:` — it is a symbol with no natural English reading. `note` was chosen as the line comment keyword: it is an English verb that reads naturally (*note that this is a workaround*) and fits the verb-first grammar of the language.

`note` on its own line opens a block comment, closed by `end`, consistent with all other block constructs. `note` after a statement on the same line acts as an inline comment.

`describe` is the documentation comment keyword. It is distinct from `note` to give tooling a clean, unambiguous signal for documentation generation without relying on position heuristics, and to make the author's intent explicit: `note` is for the developer reading the source; `describe` is for the developer consuming the API. Both support line and block (`describe … end`) forms.

### `with … and …` for object construction

`person with name "Iva" and age 30` was chosen over constructor call syntax because it reads as a natural English description of an object. The `with` introduces the first property and `and` chains additional ones.

### `in` as the universal membership and access operator

`"hello" is in myText`, `"Iva" in ages`, and `for each item in list` all use `in`. This was a deliberate choice to reduce the total number of prepositions the reader must learn. The grammatical context makes each use unambiguous.

### `is prefix of` and `is suffix of`

These were chosen over `starts with` / `ends with` to keep the noun-form pattern consistent: *"Hello" is a prefix of myText* is a noun phrase. The subject-first form (`myText starts with`) was considered but rejected because it breaks the verb-first pattern used everywhere else.

### `positions of` returns a list, never `nothing`

Rather than returning `number or nothing` for a single position, `positions of "x" in text` always returns a `list of number`. An empty list means not found. This eliminates a special case: the caller uses the same list-handling code regardless of whether zero, one, or many positions are found.

### Implicit item in `where` clauses

`filter of users where age > 18` does not require `age of item`. The compiler resolves bare property names in `where` clauses against the item type of the collection. The `of item` suffix was considered redundant and was removed after review — the context makes the referent unambiguous.

### `sort of users by descending age`

The order qualifier (`descending`, `ascending`) precedes the property name rather than following it. *Sort by descending age* reads more naturally than *sort by age descending*, where the direction feels like an afterthought.

---

## Type system decisions

### Strict compile-time types with inference

Type safety is as strict as Swift's. Implicit coercion between types is never performed. However, the type is inferred when the literal makes it unambiguous (`let name be "Iva"` → `text`). Explicit annotation is required when the type cannot be determined from the value alone.

### Reference types only — no structs

The class/struct distinction was removed. PLAIN has one kind of custom type: the class, which is always a reference type. The reasoning: application development objects have identity. A `user` passed to three functions represents one person — everyone should see the same current state. Value type semantics cause genuine beginner confusion (*why didn't my function update the object?*). The performance cases that benefit from value types — numerical computation, high-throughput data processing — are outside PLAIN's target domain.

### No generics

Generics were removed as too advanced for the target audience. PLAIN is aimed at developers who can learn the whole language in a year, including non-specialist programmers. The common use cases that generics enable (typed collections, reusable algorithms) are handled either by built-in types (`list of T`, `map of K to V`) or by accepting the constraint of working with specific types.

### `or nothing` for optional values

The absence of a value is expressed as a union: `text or nothing`. This was chosen over a separate optional type or nullable syntax because it reads clearly in English and requires no special punctuation.

---

## Feature system

### `feature` not `interface` or `protocol`

The keyword `feature` was chosen because it captures the concept precisely: a feature is something an object *can do*. `interface` is a Java-ism with baggage. `protocol` (Swift's term) is technical jargon unfamiliar to non-programmers.

### `is` for conformance declaration

`class employee is describable` reads as a natural English sentence. The same `is` keyword is used for runtime conformance checks (`if emp is describable`), keeping the total keyword count low.

### `codable` as a built-in feature

Rather than requiring developers to write serialisation code manually, `codable` is a built-in feature with compiler synthesis. When a class is declared `is codable` and all properties are JSON-mappable, encode and decode are generated automatically. Key mapping handles naming mismatches. Custom `decode` and `encode` blocks override synthesis when needed. This mirrors Swift's `Codable` design, which was the explicit inspiration.

---

## Module system

### No import declarations

All `.plain` source files in the same build target share one namespace. No `use`, `import`, or `require` declarations are needed. Name conflicts between files are a compile error — this encourages thoughtful, globally unique naming rather than namespace-as-collision-workaround. The simplicity benefit for beginners and small projects outweighs the loss of explicit dependency tracking.

---

## Concurrency

### `task function` as the unit of concurrency

Asynchronous work is declared with `task function`. The `parallel` block runs multiple task calls concurrently and guarantees all results are available when the block exits. Channels provide typed producer-consumer communication. `shared var` declares cross-task state with automatic compiler-generated synchronisation.

### Synchronous file and network I/O

File and network operations are synchronous — they block the calling thread. This was a deliberate reversal of an earlier decision to make them async. The reasoning: a simple script that reads a file should read like a simple script. Concurrency is the developer's explicit choice, not a hidden requirement of the API. When non-blocking behaviour is needed, the call is wrapped in a `task function`. This gives small programs the simplicity of shell scripts while keeping the door open for concurrent applications.

---

## Standard library grammar

### Noun form universally

All standard library functions use the noun form: `uppercase of myText`, `length of myText`, `positions of "x" in myText`. Verb form (`convert myText to uppercase`) and past participle (`uppercased myText`) were both considered and rejected. Noun form was chosen because it is the most consistent with natural English noun phrases, and consistency across the entire standard library is more valuable than local elegance in any individual function.

### `moment` as the unified date/time type

Rather than separate `date` and `time` types, PLAIN has one type: `moment`. A moment is a specific point in time. Time components are optional when constructing a moment; they default to midnight. This eliminates the common source of confusion around date-only vs datetime conversions.

### `path` as a dedicated type, not `text`

File system paths are typed as `path`, not `text`. Passing plain text where a path is expected is a compile error. Paths support dedicated operations (`name of`, `extension of`, `parent of`) that would be awkward to express as text operations. The decision was made explicitly because path-as-string is a persistent source of bugs in other languages.

---

## Transpiler

### C as the first transpiler target

C was chosen over Swift, Python, or a native compiler for the following reasons: C compiles everywhere with no additional runtime; the resulting binaries are standalone native executables; C's structure maps cleanly to PLAIN's concepts; and C is not going anywhere. The challenges (memory management, string handling, concurrency) are addressed by a generated reference-counting scheme and a runtime support library (`plain_runtime.h` / `plain_runtime.c`).

### UI deferred

Cross-platform UI in C requires a platform-specific framework (GTK, Win32, Cocoa) or a cross-platform abstraction (SDL, Dear ImGui). This was deferred from the first transpiler version to keep the initial scope tractable. The language design and UI model are complete; only the C backend implementation is pending.

---

## What was explicitly ruled out

| Idea | Reason rejected |
|---|---|
| Implicit type coercion | Causes silent bugs; clarity preferred |
| Operator overloading | Adds complexity; standard library covers the use cases |
| Null pointer / undefined | `or nothing` covers absence explicitly |
| Multiple inheritance | Increases complexity; features (interfaces) provide composition |
| Closures / lambdas | `where` clauses in collection operations cover the primary use case without introducing new concepts |
| Pattern matching | Advanced feature outside beginner scope |
| Macros / metaprogramming | Against the philosophy of readable, explicit code |
| Named formats for dates | Locale-specific; deferred to avoid internationalisation complexity |
| Struct / value types | See reference types decision above |
