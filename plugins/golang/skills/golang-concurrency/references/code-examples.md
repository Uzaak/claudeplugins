# Golang Concurrency — Code Examples

All snippets below are non-executable reference examples illustrating the rules in SKILL.md.

## Controllable Goroutine Lifetime (stop + done channels)

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

## Wait with sync.WaitGroup

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

## No Goroutines in init() — Worker with Shutdown()

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

## go.uber.org/atomic — typed atomics

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

## Avoid Mutable Globals — inject dependencies

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

```go
c := make(chan int)    // unbuffered — preferred
c := make(chan int, 1) // size 1 — acceptable
c := make(chan int, 64) // BAD — requires explicit justification
```

## Defer to Clean Up (mutex unlock)

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

```go
var mu sync.Mutex   // GOOD
mu := new(sync.Mutex) // BAD
```

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
