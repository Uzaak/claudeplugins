---
name: golang-uber-style
description: Use when writing or reviewing any Go code for style, naming, formatting, code organization, variable declarations, struct initialization, or import ordering. Apply to all Go code.
---

# Golang Uber: Style Guide

## Overview

Consistency beats personal preference. Apply these rules at the package level — not file-by-file. Code is read more than written; optimize for readers.

## Line Length

Soft limit: **99 characters**. Wrap before hitting it; don't treat it as a hard limit.

## Declarations — Group Similar

Use blocks for related declarations. Group only related items together.

```go
// GOOD
const (
    a = 1
    b = 2
)

var (
    x = 1
    y = 2
)

type (
    Area   float64
    Volume float64
)

// BAD — mixing unrelated items
const (
    Add Operation = iota + 1
    Subtract
    EnvVar = "MY_ENV"  // unrelated — separate block
)
```

Works inside functions too:

```go
func (c *client) request() {
    var (
        caller  = c.name
        format  = "json"
        timeout = 5 * time.Second
        err     error
    )
}
```

## Import Ordering

Two groups: stdlib | everything else. `goimports` handles this automatically.

```go
import (
    "fmt"
    "os"

    "go.uber.org/atomic"
    "golang.org/x/sync/errgroup"
)
```

Import aliasing: only when package name ≠ last path element, or on direct conflict:

```go
import (
    "runtime/trace"

    nettrace "golang.net/x/trace"  // conflict only
)
```

## Package Names

- All lowercase, no underscores
- Short and succinct
- Not plural (`url` not `urls`)
- Not "common", "util", "shared", "lib"

## Function Names

- Exported: `PascalCase`
- Unexported: `camelCase`
- Test functions may use underscores: `TestMyFunc_EdgeCase`

## Function Grouping and Ordering

- Group functions by receiver
- Exported functions first (after type/const/var definitions)
- `newXYZ()` after its type definition
- Utility functions at the end of the file

```go
// GOOD ordering
type something struct{ ... }

func newSomething() *something { return &something{} }
func (s *something) Cost() int { return calcCost(s.weights) }
func (s *something) Stop() { ... }

func calcCost(n []int) int { ... }  // utility at end
```

## Reduce Nesting — Return Early

Handle errors and special cases first. Keep the happy path unindented.

```go
// BAD
for _, v := range data {
    if v.F1 == 1 {
        v = process(v)
        if err := v.Call(); err == nil {
            v.Send()
        } else {
            return err
        }
    }
}

// GOOD
for _, v := range data {
    if v.F1 != 1 {
        continue
    }
    v = process(v)
    if err := v.Call(); err != nil {
        return err
    }
    v.Send()
}
```

## Unnecessary Else

```go
// BAD
var a int
if b { a = 100 } else { a = 10 }

// GOOD
a := 10
if b { a = 100 }
```

## Variable Declarations

| Situation | Form |
|---|---|
| Setting explicit value | `:=` |
| Zero value / empty slice | `var` |
| Top-level (type inferred) | `var _s = F()` |
| Top-level (explicit type needed) | `var _e error = F()` |

```go
s := "foo"          // explicit value
var filtered []int  // zero value — preferred over filtered := []int{}
```

## Prefix Unexported Globals with `_`

```go
var _defaultPort = 8080
const _maxRetries = 3
```

Exception: unexported error values use `err` prefix without underscore (`errNotFound`).

## Embedding in Structs

- Embedded types go **at the top**, blank line before regular fields
- Embed consciously: only if all exported methods should appear on the outer type
- Never embed `sync.Mutex` — always use explicit field

```go
type Client struct {
    http.Client  // embedded at top

    version int  // blank line separates
}
```

**Never embed in public structs** — it leaks implementation details and restricts future evolution.

## Nil is a Valid Slice

```go
// GOOD — return nil, not []int{}
if x == "" {
    return nil
}

// GOOD — check emptiness with len
if len(s) == 0 { ... }

// GOOD — zero-value slice is usable immediately
var nums []int
nums = append(nums, 1)
```

## Reduce Variable Scope

```go
// GOOD — err scoped to if
if err := os.WriteFile(name, data, 0644); err != nil {
    return err
}

// Use declared form when result needed outside
data, err := os.ReadFile(name)
if err != nil { return err }
```

## Avoid Naked Parameters

```go
// BAD
printInfo("foo", true, true)

// GOOD
printInfo("foo", true /* isLocal */, true /* done */)

// BETTER — use custom types
type Region int
const (
    UnknownRegion Region = iota
    Local
)
func printInfo(name string, region Region, status Status)
```

## Raw String Literals

Use backticks to avoid escaping:

```go
wantError := `unknown error:"test"`   // GOOD
wantError := "unknown error:\"test\"" // BAD
```

## Struct Initialization

```go
// GOOD — always use field names
k := User{
    FirstName: "John",
    LastName:  "Doe",
}

// GOOD — omit zero-value fields
user := User{
    FirstName: "John",  // Admin omitted — zero value
}

// GOOD — var for all-zero struct
var user User

// GOOD — &T{} for pointer, not new(T)
sptr := &T{Name: "bar"}
```

Exception: test tables with ≤3 fields may omit field names.

## Map Initialization

```go
m := make(map[T1]T2)         // empty, programmatic fill
m := make(map[T1]T2, len(x)) // with capacity hint
m := map[T1]T2{k1: v1, k2: v2} // fixed elements at init
```

## Printf Format Strings

Declare outside string literals as `const` so `go vet` can analyze them:

```go
const msg = "unexpected values %v, %v\n"
fmt.Printf(msg, 1, 2)
```

Printf-style function names must end in `f` for `go vet` detection: `Wrapf`, `Statusf`.

## Enums Start at 1

```go
type Operation int
const (
    Add Operation = iota + 1  // 1
    Subtract                   // 2
    Multiply                   // 3
)
```

Exception: when zero value is the meaningful default behavior.

## Time Handling

```go
// Use time.Time for instants, time.Duration for periods
func isActive(now, start, stop time.Time) bool { ... }
func poll(delay time.Duration) { time.Sleep(delay) }

// Calendar arithmetic
newDay := t.AddDate(0, 0, 1)   // next calendar day

// Exact duration arithmetic
in24h := t.Add(24 * time.Hour)

// When Duration can't be used — include unit in name
type Config struct {
    IntervalMillis int `json:"intervalMillis"`
}
```

## Field Tags in Marshalled Structs

Always tag JSON/YAML/etc fields to make the serialized contract explicit:

```go
type Stock struct {
    Price int    `json:"price"`
    Name  string `json:"name"`
}
```

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
