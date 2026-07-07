# Golang Style — Code Examples

All snippets below are non-executable reference examples illustrating the rules in SKILL.md.

## Declarations — Group Similar

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

## Import Ordering and Aliasing

```go
import (
    "fmt"
    "os"

    "go.uber.org/atomic"
    "golang.org/x/sync/errgroup"
)
```

```go
import (
    "runtime/trace"

    nettrace "golang.net/x/trace"  // conflict only
)
```

## Function Grouping and Ordering

```go
// GOOD ordering
type something struct{ ... }

func newSomething() *something { return &something{} }
func (s *something) Cost() int { return calcCost(s.weights) }
func (s *something) Stop() { ... }

func calcCost(n []int) int { ... }  // utility at end
```

## Reduce Nesting — Return Early

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

```go
s := "foo"          // explicit value
var filtered []int  // zero value — preferred over filtered := []int{}
```

## Prefix Unexported Globals with `_`

```go
var _defaultPort = 8080
const _maxRetries = 3
```

## Embedding in Structs

```go
type Client struct {
    http.Client  // embedded at top

    version int  // blank line separates
}
```

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

## Map Initialization

```go
m := make(map[T1]T2)         // empty, programmatic fill
m := make(map[T1]T2, len(x)) // with capacity hint
m := map[T1]T2{k1: v1, k2: v2} // fixed elements at init
```

## Printf Format Strings

```go
const msg = "unexpected values %v, %v\n"
fmt.Printf(msg, 1, 2)
```

## Enums Start at 1

```go
type Operation int
const (
    Add Operation = iota + 1  // 1
    Subtract                   // 2
    Multiply                   // 3
)
```

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

```go
type Stock struct {
    Price int    `json:"price"`
    Name  string `json:"name"`
}
```
