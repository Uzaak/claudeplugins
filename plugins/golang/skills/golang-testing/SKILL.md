---
name: golang-testing
description: Use when writing or reviewing Go tests — unit tests, integration tests, mocks, HTTP mocking, coverage, and CI test commands. Also use when tests are flaky or fail intermittently, and when deciding between table tests and individual test functions.
---

# Golang Testing

## Overview

Tests are layered: fast unit tests → integration tests with real dependencies → E2E black-box. 80% coverage is the baseline, but meaningful tests beat arbitrary coverage.

Code examples for every rule below: [references/code-examples.md](references/code-examples.md).

## Hard Rules

- Run `go test -race` for any package using goroutines, channels, or shared state.
- Use `require` for setup/preconditions; use `assert` for actual assertions.
- Never place mocks in production packages — keep them in `internal/test/` (internal mocks) or `test/fixtures/` (fixtures and shared helpers).
- Never `panic` in tests — use `t.Fatal` / `t.FailNow` so the test is marked failed and cleanup runs.
- Capture the loop variable (`tt := tt`) before `t.Parallel()`.
- Coverage baseline is 80%, but don't write trivial tests just to hit the number.
- Set `ENVIRONMENT=testing` in test context (env var or test helper).

## Test Strategy Layers

| Layer | Location | Characteristics |
|---|---|---|
| Unit | `*_test.go` alongside source | Fast, deterministic, table-driven, mocked dependencies |
| Integration | `test/` or separate package | Real DB/services, CI jobs, slower |
| E2E | Outside module | Black-box, CI/CD only |

## CI Commands

```bash
go test -v ./...                          # all tests
go test -race ./...                       # concurrency-sensitive packages
go test -coverprofile=coverage.out ./...  # coverage report
```

## Unit Tests — Table-Driven

Naming conventions: slice = `tests`, each case = `tt`, inputs prefixed `give`, outputs prefixed `want`.

## When to Split Tests (Don't Use Table)

Split into individual `Test...` functions when:
- Conditional mock expectations are needed (`if tt.shouldCallX`)
- Each case needs different setup logic
- `setupMocks func(...)` fields appear in the table struct

## Assertions and HTTP Mocking

Use testify: `require.NoError` stops the test immediately; `assert.Equal` continues on failure. Mock HTTP with `github.com/jarcoal/httpmock` (Activate / DeactivateAndReset / RegisterResponder).

## Mock Frameworks

| Framework | When to Use |
|---|---|
| Hand-written fakes | Simple interfaces, preferred for readability |
| `gomock` | Complex interactions with strict call expectations |
| `testify/mock` | When testify is already used and mock is straightforward |

## Integration Tests

- Use real databases — don't mock the DB layer
- Run in separate CI job from unit tests
- Use `testcontainers-go` or pre-provisioned test environments
- Tag with `//go:build integration` to separate from unit tests

## Common Mistakes

| Mistake | Fix |
|---|---|
| `panic("setup failed")` in test | `t.Fatal("setup failed")` |
| Loop variable captured by reference in `t.Parallel()` | Add `tt := tt` before `t.Parallel()` |
| Mocks in `internal/service/` | Move to `internal/test/` |
| Table test with `setupMocks func(...)` field | Split into separate `Test...` functions |
| `assert` for preconditions | Use `require` — stops test immediately |
| `go test ./...` without `-race` for goroutine code | Add `-race` flag |
