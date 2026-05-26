# PLAIN

**Practical Language for Applications and Intelligence**

PLAIN is a general-purpose programming language designed for the AI age. It is built for readability above all else — because AI agents write code and humans review it. Its grammar is modelled on natural English, its syntax is strict and consistent, and every construct follows one predictable rule.

---

## Design principles

- **One grammar rule** — every statement reads as `verb subject preposition value`
- **Readable by non-programmers** — natural English keywords throughout
- **Strict compile-time type safety** — with inference where the type is unambiguous
- **Concurrency as a first-class feature** — not bolted on
- **No cryptic symbols** — no `{}`, `=>`, `::`, `?:`, `!!`
- **Enforced indentation** — 4 spaces, always, compiler-enforced
- **Cross-platform** — compiles to C, runs anywhere

---

## Quick example

```plain
class person is codable
    property name as text
    property age  as number
end

feature greeter
    function greet returns text
end

class employee extends person is greeter
    property department as text

    init with name as text and age as number and department as text
        set this->name       to name
        set this->age        to age
        set this->department to department
    end

    function greet returns text
        return "Hello, I am " + this->name + " from " + this->department
    end
end

task function loadEmployees returns list of employee
    let response be response of get from "https://api.example.com/employees"
    return list of employee from json body of response
end

task function main
    parallel
        let employees be await loadEmployees
        let count     be await fetchCount
    end

    for each emp in sort of employees by name
        print emp->greet
    end
end
```

---

## Repository structure

```
plain-lang/
    specification/          Language and standard library specification
    documentation/          Guides and reference
    tutorial/               Step-by-step learning path
    examples/               Runnable example programs
    transpiler/             PLAIN → C transpiler (Swift)
        Sources/PlainLang/  Transpiler source
        Runtime/            C runtime support library
    tools/                  plain build, plain run, plain check
```

---

## Getting started

See [documentation/getting-started.md](documentation/getting-started.md).

---

## Status

PLAIN is in active design and early implementation. The language specification is complete. The transpiler is under development.

---

## Licence

MIT
