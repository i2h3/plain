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
        set this->title to title
        set this->done  to false
    end
    function display returns text
        let mark be if this->done then "[x]" else "[ ]"
        return mark + " " + this->title
    end
end
```

### Positive

```plain
class todo
    property title as text
    property done  as bool

    init with title as text
        set this->title to title
        set this->done  to false
    end

    function display returns text
        let mark be if this->done then "[x]" else "[ ]"
        return mark + " " + this->title
    end
end
```

## Dedicated Source Code Files

Put classes, top-level functions, and features into dedicated source code files instead of everything into one huge source code file, unless technically necessary as in the case of a self-contained script.

## Main File Name

The entry point of any project should be called `main.plain` by default.