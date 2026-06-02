---
name: golang-uber-concurrency
description: Use when writing goroutines, using sync primitives, channels, atomic operations, shared state, mutexes, or defer for cleanup in Go. Also use when reviewing concurrent code for leaks or race conditions.
---

# Golang Uber: Concurrency & Safety

## Overview

Goroutines are not free. Leaked goroutines cause memory pressure, prevent GC, and hold resources. Every goroutine must have a controlled lifetime. Shared state must be protected without leaking synchronization details.

## Don't Fire-and-Forget Goroutines

Every goroutine must have:
- A way to signal it to stop, AND
- A way to wait for it to finish

```go
// BAD — no stop mechanism, runs until process exits
go func() {
    for {
        flush()
        time.Sleep(delay)
    }
}()

// GOOD — controllable lifetime
var (
    stop = make(chan struct{})
    done = make(chan struct{})
)
go func() {
    defer close(done)
    ticker := time.NewTicker(delay)
    defer ticker.Stop()
    for {
        select {
        case <-ticker.C:
            flush()
        case <-stop:
            return
        }
    }
}()

// Shutdown:
close(stop)
<-done
```

## Wait for Goroutines to Exit

- **Multiple goroutines:** use `sync.WaitGroup`
- **Single goroutine:** use `done chan struct{}` with `defer close(done)`

```go
// Multiple
var wg sync.WaitGroup
for i := 0; i < N; i++ {
    wg.Add(1)
    go func() {
        defer wg.Done()
        // work
    }()
}
wg.Wait()
```

## No Goroutines in `init()`

Expose an object that manages the goroutine lifecycle instead:

```go
// BAD
func init() { go doWork() }

// GOOD
type Worker struct {
    stop chan struct{}
    done chan struct{}
}

func NewWorker() *Worker {
    w := &Worker{stop: make(chan struct{}), done: make(chan struct{})}
    go w.run()
    return w
}

func (w *Worker) Shutdown() {
    close(w.stop)
    <-w.done
}
```

## Use go.uber.org/atomic

Raw `sync/atomic` operates on primitive types — easy to accidentally do non-atomic reads. Use `go.uber.org/atomic` for type safety:

```go
// BAD — race on read
type foo struct { running int32 }
func (f *foo) isRunning() bool { return f.running == 1 }

// GOOD
type foo struct { running atomic.Bool }
func (f *foo) isRunning() bool { return f.running.Load() }
func (f *foo) start() {
    if f.running.Swap(true) { return } // already running
}
```

## Avoid Mutable Globals

Use dependency injection instead:

```go
// BAD — hard to test, shared mutation
var _timeNow = time.Now
func sign(msg string) string { now := _timeNow(); ... }

// GOOD
type signer struct { now func() time.Time }
func newSigner() *signer { return &signer{now: time.Now} }
func (s *signer) Sign(msg string) string { now := s.now(); ... }
```

## Channel Size is One or None

Default: unbuffered. Acceptable: size 1. Any other size requires documented justification.

```go
c := make(chan int)    // unbuffered — preferred
c := make(chan int, 1) // size 1 — acceptable
c := make(chan int, 64) // BAD — requires explicit justification
```

## Defer to Clean Up

Always use `defer` for mutex unlocks and resource cleanup — prevents missed unlocks on multiple return paths:

```go
// BAD — easy to miss unlock
p.Lock()
if p.count < 10 {
    p.Unlock()
    return p.count
}
p.count++
newCount := p.count
p.Unlock()
return newCount

// GOOD
p.Lock()
defer p.Unlock()
if p.count < 10 {
    return p.count
}
p.count++
return p.count
```

## Copy Slices and Maps at Boundaries

Storing a reference allows callers to mutate internal state:

```go
// BAD — caller can mutate d.trips
func (d *Driver) SetTrips(trips []Trip) { d.trips = trips }

// GOOD
func (d *Driver) SetTrips(trips []Trip) {
    d.trips = make([]Trip, len(trips))
    copy(d.trips, trips)
}

// BAD — returns direct reference to internal map
func (s *Stats) Snapshot() map[string]int { return s.counters }

// GOOD — return a copy
func (s *Stats) Snapshot() map[string]int {
    s.mu.Lock()
    defer s.mu.Unlock()
    result := make(map[string]int, len(s.counters))
    for k, v := range s.counters { result[k] = v }
    return result
}
```

## Zero-Value Mutexes

`sync.Mutex` and `sync.RWMutex` zero values are valid — never use `new()`:

```go
var mu sync.Mutex   // GOOD
mu := new(sync.Mutex) // BAD
```

**Never embed mutexes in structs** — it leaks `Lock()`/`Unlock()` as public API:

```go
// BAD — Lock/Unlock become public
type SMap struct {
    sync.Mutex
    data map[string]string
}

// GOOD — hidden implementation detail
type SMap struct {
    mu   sync.Mutex
    data map[string]string
}
func (m *SMap) Get(k string) string {
    m.mu.Lock()
    defer m.mu.Unlock()
    return m.data[k]
}
```

## Interface Compliance Verification

For exported types that must implement an interface, verify at compile time:

```go
var _ http.Handler = (*Handler)(nil)   // pointer receiver
var _ http.Handler = LogHandler{}      // value receiver
```

This fails at compile time if the interface is ever broken.

## Receivers and Interfaces

- Value receiver methods can be called on both values and pointers
- Pointer receiver methods can only be called on pointers (or addressable values)
- Map values are not addressable — store `map[int]*S` if you need pointer receivers

## Common Mistakes

| Mistake | Fix |
|---|---|
| `go func() { for { work() } }()` | Add `stop` channel + `done` channel |
| `func init() { go doWork() }` | Expose `NewWorker()` with `Shutdown()` |
| `atomic.AddInt32(&f.running, 1)` | Use `atomic.Bool` / `go.uber.org/atomic` |
| `var _now = time.Now` then mutated in tests | Inject `now func() time.Time` via DI |
| `make(chan int, 100)` | Use unbuffered or size-1; document if larger |
| Embedding `sync.Mutex` in struct | Use explicit field `mu sync.Mutex` |
| Returning `s.internalMap` directly | Copy before returning |
| `mu := new(sync.Mutex)` | `var mu sync.Mutex` |
