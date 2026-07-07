---
name: golang-errors-safety
description: Use when writing Go functions that return errors, handle errors from callees, use type assertions, call panic, or use os.Exit. Also use when reviewing error handling code or designing error types for a package.
---

# Golang Errors & Safety

## Overview

Go error handling is explicit by design. Every error must be handled once, named consistently, and propagated with context. Panics are not an error strategy.

Code examples for every rule below: [references/code-examples.md](references/code-examples.md).

## Hard Rules

- **Handle errors once.** Never log AND return. Choose exactly one: wrap and return (`fmt.Errorf("get user %q: %w", id, err)`); log and degrade gracefully (non-critical path); or match a specific error with `errors.Is`, degrade for it, and propagate the rest.
- **Wrap with `%w`** so callers can use `errors.Is`/`errors.As`; use `%v` only to intentionally break the chain. Keep context succinct: `"new store: %w"`, not `"failed to create new store: %w"` — chains read left-to-right.
- **Type assertions: always comma-ok** (`t, ok := i.(string)`); the single-return form panics on the wrong type.
- **Don't panic** in production code — return errors. `panic` only for truly irrecoverable situations. Exception: `template.Must(...)` and similar at program init. In tests: `t.Fatal` / `t.FailNow`, never `panic`.
- **`os.Exit` and `log.Fatal*` only in `main()`**, called at most once. Put all logic in a `run() error` function.
- **Avoid `init()`.** If used, it must be: (1) completely deterministic regardless of environment, (2) independent of other `init()` functions, (3) free of global/env state access, (4) free of I/O (filesystem, network, syscalls). Prefer `var _defaultFoo = defaultFoo()` constructor functions. Exception: pluggable hooks (`database/sql` dialects, encoding registries).
- **Never shadow built-in names**: `error`, `string`, `len`, `new`, `make`, `close`, `cap`, etc.

## Error Types — Decision Table

| Caller needs to match? | Message | Guidance |
|---|---|---|
| No | static | `errors.New("...")` |
| No | dynamic | `fmt.Errorf("context: %v", detail)` |
| Yes | static | `var ErrNotFound = errors.New("not found")` |
| Yes | dynamic | custom `type NotFoundError struct { ... }` implementing `error` |

## Error Naming

- Exported error variables: `ErrNotFound`, `ErrCouldNotOpen`
- Unexported error variables: `errNotFound` (exception to the `_` prefix rule — no underscore)
- Custom error types: `NotFoundError`, `resolveError` (suffix `Error`)

## Common Mistakes

| Mistake | Fix |
|---|---|
| `log.Printf(err); return err` | Choose: wrap+return OR log+degrade |
| `panic("bad input")` | Return an error |
| `t := i.(string)` | `t, ok := i.(string)` |
| `log.Fatal(err)` outside `main` | Return error up the stack |
| `func init() { os.ReadFile(...) }` | Move I/O to a `load()` function called from `main` |
| `var ErrFoo = errors.New("foo")` then used unexported | Use `errFoo` for unexported |
