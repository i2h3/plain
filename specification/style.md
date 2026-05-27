# Style

This document provides guidelines on formatting PLAIN source code for the best reading experience.

## Trim Trailing Whitespace

Always remove all spaces and tabs and other whitespace characters at the end of lines.

## Blank Lines

Separate blocks from other members with a single blank line.

### Negative

```plain
class todo
    property title as text
    property done  as bool
    init with title as text
        set title of this to title
        set done  of this to false
    end
    function display returns text
        let mark be if done of this then "[x]" else "[ ]"
        return mark + " " + title of this
    end
end
```

### Positive

```plain
class todo
    property title as text
    property done  as bool

    init with title as text
        set title of this to title
        set done  of this to false
    end

    function display returns text
        let mark be if done of this then "[x]" else "[ ]"
        return mark + " " + title of this
    end
end
```

## Feature Names

Name features using the form that best completes the sentence `class X is Y` as natural English.

Use an **agent noun** (ending in `-er` or `-or`) when the feature describes an active role — something the implementing type does:

```plain
feature greeter
    function greet returns text
end

feature renderer
    function render returns nothing
end
```

`class employee is greeter` reads as "an employee is a greeter". The noun describes the role the type plays.

Use an **adjective** (ending in `-able` or `-ible`) when the feature describes a passive capability — something that can be done to the implementing type:

```plain
feature codable
    function encode returns text
    function decode from text returns nothing
end

feature sortable
    function compare with other as this returns number
end
```

`class user is codable` reads as "a user is codable". The adjective describes what can be done to the type.

### Quick test

Read `class X is Y` aloud. If it sounds like a role or profession, use an agent noun. If it sounds like a trait or property, use an adjective.

### Negative

```plain
feature greeting      note gerund — sounds like an action in progress, not a trait
feature greetable     note -able — implies the type can be greeted, not that it greets
```

### Positive

```plain
feature greeter       note agent noun — the type actively greets
feature describable   note adjective — the type can be described
```

## Dedicated Source Code Files

Put classes, top-level functions, and features into dedicated source code files instead of everything into one huge source code file, unless technically necessary as in the case of a self-contained script.

## Main File Name

The entry point of any project should be called `main.plain` by default.