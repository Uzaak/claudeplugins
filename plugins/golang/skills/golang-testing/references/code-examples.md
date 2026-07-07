# Golang Testing — Code Examples

All snippets below are non-executable reference examples illustrating the rules in SKILL.md.

## Table-Driven Unit Test

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

## Parallel Tests — capture loop variable

```go
for _, tt := range tests {
    tt := tt  // required — capture range variable
    t.Run(tt.give, func(t *testing.T) {
        t.Parallel()
        // use tt safely here
    })
}
```

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
