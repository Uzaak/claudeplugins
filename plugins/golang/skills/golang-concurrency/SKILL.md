---
name: golang-concurrency
description: Use when writing goroutines, using sync primitives, channels, atomic operations, shared state, mutexes, or defer for cleanup in Go. Also use when reviewing concurrent code for leaks or race conditions.
---

# Golang Concurrency & Safety

## Overview

Goroutines are not free. Leaked goroutines cause memory pressure, prevent GC, and hold resources. Every goroutine must have a controlled lifetime. Shared state must be protected without leaking synchronization details.

Code examples for every rule below: [references/code-examples.md](references/code-examples.md).

## Hard Rules

- **No fire-and-forget goroutines.** Every goroutine needs a way to be signalled to stop AND a way to be waited on: `sync.WaitGroup` for multiple goroutines, `done chan struct{}` with `defer close(done)` for a single one.
- **No goroutines in `init()`** — expose an object (`NewWorker()` / `Shutdown()`) that manages the lifecycle.
- **Channel size is one or none.** Default unbuffered; size 1 acceptable; anything larger requires documented justification.
- **Always `defer` mutex unlocks** and resource cleanup — prevents missed unlocks on multiple return paths.
- **Copy slices and maps at boundaries** — both when storing caller-provided ones and when returning internal ones; otherwise callers can mutate internal state.
- **Zero-value mutexes are valid:** `var mu sync.Mutex`, never `new(sync.Mutex)`.
- **Never embed mutexes in structs** — it leaks `Lock()`/`Unlock()` as public API. Use an explicit `mu sync.Mutex` field.
- **Use `go.uber.org/atomic`**, not raw `sync/atomic` — typed atomics (`atomic.Bool`) prevent accidental non-atomic reads.
- **Avoid mutable globals** (e.g. `var _timeNow = time.Now`) — inject dependencies instead (`signer{now: time.Now}`).

## Interface Compliance Verification

For exported types that must implement an interface, verify at compile time:

```go
var _ http.Handler = (*Handler)(nil)   // pointer receiver
var _ http.Handler = LogHandler{}      // value receiver
```

## Receivers and Interfaces

- Value receiver methods can be called on both values and pointers.
- Pointer receiver methods can only be called on pointers (or addressable values).
- Map values are not addressable — store `map[int]*S` if you need pointer receivers.

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
