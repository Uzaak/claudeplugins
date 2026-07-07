---
name: golang-patterns
description: Use when writing Go tests (table-driven, parallel), designing public APIs with optional arguments, or setting up linting. Also use when choosing between multiple test cases vs a table test, or designing a constructor with 3+ optional parameters.
---

# Golang Patterns, Performance & Linting

## Overview

Test tables, functional options, hot-path performance, and linting baselines for Go code.

Code examples for every rule below: [references/code-examples.md](references/code-examples.md).

## Hard Rules

- **Always** capture the loop variable (`tt := tt`) before calling `t.Parallel()`.
- Run `golangci-lint run ./...` in CI with at minimum: `errcheck`, `goimports`, `golint`, `govet`, `staticcheck`.
- Apply performance patterns only in hot paths — premature optimization harms readability.
- Table-test naming is mandatory: slice = `tests`, case = `tt`, inputs prefixed `give`, outputs prefixed `want`.

## Test Tables

Use table-driven tests when the same logic runs against multiple inputs.

Split into separate `Test...` functions when:
- You need conditional mock expectations (`if tt.shouldCallX`)
- You have `setupMocks func(*FooMock)` fields in the table
- You need multiple branching paths through the test body
- Different cases require fundamentally different setup

A simple `wantErr bool` field for success/failure branching is acceptable.

## Functional Options

Use for constructors with optional arguments — especially when 3+ options exist or the API may expand.

Preferred implementation: an `Option` interface with an unexported `apply(*options)` method — not closures. Interface-based options can be compared in tests and can implement `fmt.Stringer`. Full implementation and usage in the reference file.

## Performance (hot paths only)

- Use `strconv.Itoa` over `fmt.Sprint` for primitive conversions (~64 vs ~143 ns/op).
- Convert a fixed string to `[]byte` once, outside the loop — not on every iteration.
- Specify container capacity: `make(map[K]V, n)` is a hint; `make([]T, 0, n)` is guaranteed preallocation (zero subsequent allocs until full).

## Linting

| Linter | Purpose |
|---|---|
| `errcheck` | Ensure errors are handled |
| `goimports` | Format code and manage imports |
| `golint` | Point out common style mistakes |
| `govet` | Analyze code for common mistakes |
| `staticcheck` | Static analysis checks |

CI command: `golangci-lint run ./...`

## Common Mistakes

| Mistake | Fix |
|---|---|
| `shouldCallX bool` field in table test | Split into separate `TestX` functions |
| `go func() { for _, tt := range tests { t.Parallel() } }` | `tt := tt` before `t.Parallel()` |
| `func Open(addr string, cache bool, log *Logger)` with 3+ params | Use functional options |
| `func WithFoo(x bool) Option { return func(o *opts) { o.foo=x } }` | Use interface-based option (allows comparison) |
| `fmt.Sprint(rand.Int())` in hot path | `strconv.Itoa(rand.Int())` |
| `data = append(data, item)` in loop without capacity | `make([]T, 0, expectedSize)` |
