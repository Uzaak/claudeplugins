---
name: golang-testing
description: Use when writing or reviewing Go tests — unit tests, integration tests, mocks, HTTP mocking, coverage, and CI test commands. Also use when deciding between table tests and individual test functions.
---

# Golang Testing

## Overview

Tests are layered: fast unit tests → integration tests with real dependencies → E2E black-box. 80% coverage is the baseline, but meaningful tests beat arbitrary coverage.

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

Run `go test -race` for any package using goroutines, channels, or shared state.

## Coverage

- Minimum baseline: **80%**
- Prefer meaningful tests — don't write trivial tests to hit coverage numbers

## Unit Tests — Table-Driven (Uber Convention)

```go
func TestSplitHostPort(t *testing.T) {
    tests := []struct {
        give     string
        wantHost string
        wantPort string
    }{
        {give: "192.0.2.0:8000", wantHost: "192.0.2.0", wantPort: "8000"},
        {give: ":8000",          wantHost: "",           wantPort: "8000"},
    }

    for _, tt := range tests {
        t.Run(tt.give, func(t *testing.T) {
            host, port, err := net.SplitHostPort(tt.give)
            require.NoError(t, err)
            assert.Equal(t, tt.wantHost, host)
            assert.Equal(t, tt.wantPort, port)
        })
    }
}
```

**Naming conventions:** slice = `tests`, each case = `tt`, inputs prefixed `give`, outputs prefixed `want`.

## Parallel Tests

Always capture loop variable before `t.Parallel()`:

```go
for _, tt := range tests {
    tt := tt  // required — capture range variable
    t.Run(tt.give, func(t *testing.T) {
        t.Parallel()
        // use tt safely here
    })
}
```

## When to Split Tests (Don't Use Table)

Split into individual `Test...` functions when:
- Conditional mock expectations are needed (`if tt.shouldCallX`)
- Each case needs different setup logic
- `setupMocks func(...)` fields appear in the table struct

## Assertions — testify

```go
import (
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

require.NoError(t, err)          // stops test immediately on failure
assert.Equal(t, expected, got)   // continues test on failure
assert.EqualError(t, err, "msg")
```

Use `require` for setup/preconditions. Use `assert` for actual assertions.

## HTTP Mocking — httpmock

```go
import "github.com/jarcoal/httpmock"

func TestMyService(t *testing.T) {
    httpmock.Activate()
    defer httpmock.DeactivateAndReset()

    httpmock.RegisterResponder("GET", "https://api.example.com/users/1",
        httpmock.NewJsonResponderOrPanic(200, map[string]any{"id": 1}),
    )

    // call code that makes HTTP requests
}
```

## Mock Frameworks

| Framework | When to Use |
|---|---|
| Hand-written fakes | Simple interfaces, preferred for readability |
| `gomock` | Complex interactions with strict call expectations |
| `testify/mock` | When testify is already used and mock is straightforward |

## Mock Location

Keep mocks and test doubles in:
- `internal/test/` — internal mocks
- `test/fixtures/` — test fixtures and shared helpers

Never place mocks in production packages.

## Test Context

```go
// Set ENVIRONMENT=testing in test context
os.Setenv("ENVIRONMENT", "testing")
// or inject via test helper
```

## Don't Panic in Tests

```go
// BAD
if err != nil { panic("setup failed") }

// GOOD
if err != nil { t.Fatal("setup failed:", err) }
```

Use `t.Fatal` or `t.FailNow` — ensures test is marked as failed and cleanup runs.

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
