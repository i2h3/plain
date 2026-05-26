# PLAIN Language Support for Visual Studio Code

Syntax highlighting for the [PLAIN programming language](../README.md). PLAIN source files use the `.plain` extension.

## What is highlighted

| Token | Scope | Typical colour |
|---|---|---|
| `//` line comments | `comment.line` | grey |
| String literals | `string.quoted.double` | orange / warm |
| Numeric literals | `constant.numeric` | green / teal |
| `true` `false` `nothing` | `constant.language` | blue |
| `this` `parent` | `variable.language` | red / special |
| Function and task names | `entity.name.function` | yellow |
| Class, feature, error names | `entity.name.type` | teal |
| Declaration keywords (`let` `var` `function` `class` …) | `storage.type` | blue / purple |
| Control flow (`if` `else` `while` `for` `end` `try` `catch` …) | `keyword.control` | red / coral |
| Word operators (`is` `and` `or` `not`) | `keyword.operator.word` | orange |
| Built-in types (`text` `number` `decimal` `bool` `list` …) | `support.type` | teal |
| Structural keywords (`be` `as` `to` `from` `of` `set` `print` …) | `keyword.other` | grey-blue |
| Standard library functions (`sort` `filter` `length` `round` …) | `support.function.builtin` | green |
| `->` member access | `keyword.operator.accessor` | yellow |
| Member name after `->` | `variable.other.member` | light |
| Arithmetic `+ - * /` | `keyword.operator.arithmetic` | white |
| Comparison `> < >= <=` | `keyword.operator.comparison` | white |

Exact colours depend on the active VS Code colour theme.

## Language features

- Single-line comment toggling with `//`
- Auto-close for double-quoted strings
- Auto-indent after block-opening keywords (`if`, `function`, `class`, `for`, `while`, `try`, `catch`, `parallel`, `init`, `decode`, `encode`)
- Auto-dedent when `end`, `else`, or `catch` is typed

## Loading the extension locally

### Option A — Install from folder (no build tools required)

```sh
ln -s "$(pwd)" ~/.vscode/extensions/plain-language-0.0.1
```

Run this command from inside the `visualstudiocode/` directory, then restart VS Code.

### Option B — Extension Development Host

1. Open the `visualstudiocode/` folder in VS Code.
2. Press **F5**. A new VS Code window opens with the extension active.
3. Open any `.plain` file in the new window.

### Option C — Package and install

Requires the `vsce` tool (`npm install -g @vscode/vsce`):

```sh
cd visualstudiocode
vsce package
code --install-extension plain-language-0.0.1.vsix
```

## Structure

```
visualstudiocode/
    package.json                  Extension manifest
    language-configuration.json   Comment toggling, auto-indent rules
    syntaxes/
        plain.tmLanguage.json     TextMate grammar
    README.md                     This file
```
