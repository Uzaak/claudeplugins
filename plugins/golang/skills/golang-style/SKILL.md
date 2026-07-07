---
name: golang-style
description: Use when writing or reviewing any Go code for style, naming, formatting, code organization, variable declarations, struct initialization, or import ordering. Apply to all Go code.
---

# Golang Style Guide

## Overview

Consistency beats personal preference. Apply these rules at the package level — not file-by-file. Code is read more than written; optimize for readers.

Code examples for every rule below: [references/code-examples.md](references/code-examples.md).

## Core Rules

- **Line length:** soft limit 99 characters — wrap before hitting it; not a hard limit.
- **Declarations:** group related declarations in blocks (`const (...)`, `var (...)`, `type (...)`); never mix unrelated items in one block. Works inside functions too.
- **Imports:** two groups — stdlib, then everything else (`goimports` handles it). Alias only when the package name ≠ last path element, or on a direct conflict.
- **Package names:** all lowercase, no underscores, short, not plural (`url` not `urls`), never `common`/`util`/`shared`/`lib`.
- **Function names:** exported `PascalCase`, unexported `camelCase`; test functions may use underscores (`TestMyFunc_EdgeCase`).
- **Function ordering:** group by receiver; exported functions first (after type/const/var); `newXYZ()` right after its type definition; utility functions at the end of the file.
- **Nesting:** handle errors and special cases first; keep the happy path unindented; drop unnecessary `else` (`a := 10; if b { a = 100 }`).
- **Unexported globals:** prefix with `_` (`_defaultPort`, `_maxRetries`). Exception: unexported error values use the `err` prefix without underscore (`errNotFound`).
- **Embedding:** embedded types at the top of the struct, blank line before regular fields; embed only if all exported methods should appear on the outer type; **never embed `sync.Mutex`**; **never embed in public structs** — it leaks implementation details and restricts evolution.
- **Nil is a valid slice:** return `nil`, not `[]int{}`; check emptiness with `len(s) == 0`; a zero-value slice is immediately usable with `append`.
- **Variable scope:** use `if err := f(); err != nil` when the result isn't needed outside; declared form when it is.
- **Naked parameters:** comment bool literals (`true /* isLocal */`) or, better, replace with custom types.
- **Raw strings:** use backticks to avoid escaping (`` `unknown error:"test"` ``).
- **Struct initialization:** always use field names (exception: test tables with ≤3 fields); omit zero-value fields; `var user User` for an all-zero struct; `&T{Name: "bar"}` instead of `new(T)`.
- **Printf:** declare format strings as `const` (so `go vet` can analyze); printf-style function names must end in `f` (`Wrapf`, `Statusf`).
- **Enums:** start at 1 (`iota + 1`) unless the zero value is the meaningful default.
- **Time:** `time.Time` for instants, `time.Duration` for periods; `t.AddDate(0, 0, 1)` for calendar math, `t.Add(24 * time.Hour)` for exact durations; when Duration can't be used, put the unit in the name (`IntervalMillis`).
- **Field tags:** always tag JSON/YAML/etc fields in marshalled structs — the serialized contract must be explicit.

## Variable Declarations

| Situation | Form |
|---|---|
| Setting explicit value | `:=` |
| Zero value / empty slice | `var` |
| Top-level (type inferred) | `var _s = F()` |
| Top-level (explicit type needed) | `var _e error = F()` |

## Map Initialization

`make(map[T1]T2)` for empty/programmatic fill; `make(map[T1]T2, len(x))` with a capacity hint; map literal for fixed elements at init.

## Common Mistakes

| Mistake | Fix |
|---|---|
| `import "fmt"; import "os"` | Single grouped `import (...)` block |
| Package named `utils` or `common` | Rename to something specific |
| `user := User{}` (zero value) | `var user User` |
| `sptr := new(T); sptr.Name = "x"` | `sptr := &T{Name: "x"}` |
| `return []int{}` | `return nil` |
| `if s == nil { }` to check empty | `if len(s) == 0 { }` |
| `var _s string = F()` (redundant type) | `var _s = F()` |
| `const defaultPort = 8080` (unexported global) | `const _defaultPort = 8080` |
| Printf format string as `var msg =` | `const msg =` |
