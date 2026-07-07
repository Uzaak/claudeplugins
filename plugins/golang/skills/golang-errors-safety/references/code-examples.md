# Golang Errors & Safety — Code Examples

All snippets below are non-executable reference examples illustrating the rules in SKILL.md.

## Static vs Dynamic Matchable Errors

```go
// Static, matchable
var ErrCouldNotOpen = errors.New("could not open")

// Dynamic, matchable
type NotFoundError struct { File string }
func (e *NotFoundError) Error() string {
    return fmt.Sprintf("file %q not found", e.File)
}
```

## Error Wrapping — succinct context

```go
// Bad
return fmt.Errorf("failed to create new store: %w", err)
// Good
return fmt.Errorf("new store: %w", err)
```

## Handle Errors Once (all four patterns)

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

## Type Assertion — comma-ok

```go
// BAD
t := i.(string)

// GOOD
t, ok := i.(string)
if !ok {
    // handle gracefully
}
```

## Don't Panic — return errors

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

## Exit in Main Only — run() pattern

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

## Avoid init() — constructor functions

```go
// BAD
var _defaultFoo Foo
func init() { _defaultFoo = Foo{...} }

// GOOD
var _defaultFoo = defaultFoo()
func defaultFoo() Foo { return Foo{...} }
```

## Avoid Built-In Names

```go
// BAD
var error string
func handleErrorMessage(error string) { ... }

// GOOD
var errorMessage string
func handleErrorMessage(msg string) { ... }
```
