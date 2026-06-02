---
name: golang-uber-errors-safety
description: Use when writing Go functions that return errors, handle errors from callees, use type assertions, call panic, or use os.Exit. Also use when reviewing error handling code or designing error types for a package.
---

# Golang Uber: Errors & Safety

## Overview

Go error handling is explicit by design. Every error must be handled once, named consistently, and propagated with context. Panics are not an error strategy.

## Error Types — Decision Table

| Caller needs to match? | Message | Guidance |
|---|---|---|
| No | static | `errors.New("...")` |
| No | dynamic | `fmt.Errorf("context: %v", detail)` |
| Yes | static | `var ErrNotFound = errors.New("not found")` |
| Yes | dynamic | custom `type NotFoundError struct { ... }` implementing `error` |

```go
// Static, matchable
var ErrCouldNotOpen = errors.New("could not open")

// Dynamic, matchable
type NotFoundError struct { File string }
func (e *NotFoundError) Error() string {
    return fmt.Sprintf("file %q not found", e.File)
}
```

## Error Wrapping

- Use `%w` → caller can use `errors.Is`/`errors.As` (default for most wrapping)
- Use `%v` → hides underlying error from callers (use to intentionally break chain)
- Keep context **succinct**: `"new store: %w"` NOT `"failed to create new store: %w"`

```go
// Bad
return fmt.Errorf("failed to create new store: %w", err)
// Good
return fmt.Errorf("new store: %w", err)
```

Error chains read left-to-right: `x: y: new store: the error` — avoid redundant prefixes.

## Error Naming

- Exported error variables: `ErrNotFound`, `ErrCouldNotOpen`
- Unexported error variables: `errNotFound` (exception to `_` prefix rule — no underscore)
- Custom error types: `NotFoundError`, `resolveError` (suffix `Error`)

## Handle Errors Once

Never log AND return. Choose exactly one:

```go
// BAD: log and return
log.Printf("Could not get user: %v", err)
return err

// GOOD: wrap and return (let caller handle)
return fmt.Errorf("get user %q: %w", id, err)

// GOOD: log and degrade gracefully (non-critical path)
if err := emitMetrics(); err != nil {
    log.Printf("Could not emit metrics: %v", err)
    // continue — metrics are optional
}

// GOOD: match specific error, degrade; else propagate
if errors.Is(err, ErrUserNotFound) {
    tz = time.UTC
} else {
    return fmt.Errorf("get user %q: %w", id, err)
}
```

## Type Assertion Failures

Always use comma-ok. Single-return panics on incorrect type:

```go
// BAD
t := i.(string)

// GOOD
t, ok := i.(string)
if !ok {
    // handle gracefully
}
```

## Don't Panic

- Return errors instead of panicking in production code
- `panic` only for truly irrecoverable situations (nil dereference)
- Exception: `template.Must(...)` and similar at program init is acceptable
- In tests: use `t.Fatal` / `t.FailNow` — never `panic`

```go
// BAD
func run(args []string) {
    if len(args) == 0 { panic("argument required") }
}

// GOOD
func run(args []string) error {
    if len(args) == 0 { return errors.New("argument required") }
    return nil
}
```

## Exit in Main Only

- `os.Exit` and `log.Fatal*` belong **only in `main()`**
- Use a `run() error` function for all business logic
- Call `os.Exit` **at most once**

```go
func main() {
    if err := run(); err != nil {
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }
}

func run() error {
    // all logic here — return errors
}
```

## Avoid `init()`

`init()` must be:
1. Completely deterministic regardless of environment
2. Independent of other `init()` functions
3. Free of global/env state access
4. Free of I/O (filesystem, network, syscalls)

Prefer constructor functions:

```go
// BAD
var _defaultFoo Foo
func init() { _defaultFoo = Foo{...} }

// GOOD
var _defaultFoo = defaultFoo()
func defaultFoo() Foo { return Foo{...} }
```

Exception: pluggable hooks (`database/sql` dialects, encoding registries).

## Avoid Built-In Names

Never shadow: `error`, `string`, `len`, `new`, `make`, `close`, `cap`, etc.

```go
// BAD
var error string
func handleErrorMessage(error string) { ... }

// GOOD
var errorMessage string
func handleErrorMessage(msg string) { ... }
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| `log.Printf(err); return err` | Choose: wrap+return OR log+degrade |
| `panic("bad input")` | Return an error |
| `t := i.(string)` | `t, ok := i.(string)` |
| `log.Fatal(err)` outside `main` | Return error up the stack |
| `func init() { os.ReadFile(...) }` | Move I/O to a `load()` function called from `main` |
| `var ErrFoo = errors.New("foo")` then used unexported | Use `errFoo` for unexported |
