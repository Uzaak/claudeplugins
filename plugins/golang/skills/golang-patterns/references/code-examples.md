# Golang Patterns — Code Examples

All snippets below are non-executable reference examples illustrating the rules in SKILL.md.

## Table-Driven Test (naming conventions)

```go
// Slice is named "tests", each case is "tt"
// Input fields prefixed "give", output fields prefixed "want"
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
```

## When NOT to Use Table Tests

```go
// BAD — conditional mock setup inside table
for _, tt := range tests {
    if tt.shouldCallX {
        xMock.EXPECT().Call().Return(tt.giveXResponse, tt.giveXErr)
    }
}

// GOOD — separate test functions
func TestShouldCallX(t *testing.T) {
    xMock.EXPECT().Call().Return("XResponse", nil)
    got, err := DoComplexThing("inputX", xMock, yMock)
    require.NoError(t, err)
    assert.Equal(t, "want", got)
}
```

## Parallel Tests — capture loop variable

```go
for _, tt := range tests {
    tt := tt  // capture range variable — required for t.Parallel
    t.Run(tt.give, func(t *testing.T) {
        t.Parallel()
        // test body uses tt safely
    })
}
```

## Functional Options — full implementation

```go
type options struct {
    cache  bool
    logger *zap.Logger
}

type Option interface {
    apply(*options)
}

type cacheOption bool
func (c cacheOption) apply(opts *options) { opts.cache = bool(c) }
func WithCache(c bool) Option { return cacheOption(c) }

type loggerOption struct{ Log *zap.Logger }
func (l loggerOption) apply(opts *options) { opts.logger = l.Log }
func WithLogger(log *zap.Logger) Option { return loggerOption{Log: log} }

func Open(addr string, opts ...Option) (*Connection, error) {
    options := options{cache: true, logger: zap.NewNop()}
    for _, o := range opts {
        o.apply(&options)
    }
    // ...
}
```

## Functional Options — usage

```go
db.Open(addr)
db.Open(addr, db.WithLogger(log))
db.Open(addr, db.WithCache(false), db.WithLogger(log))
```

## strconv over fmt

```go
// BAD — 143 ns/op
s := fmt.Sprint(rand.Int())

// GOOD — 64 ns/op
s := strconv.Itoa(rand.Int())
```

## Avoid Repeated String-to-Byte Conversions

```go
// BAD — allocates []byte on every iteration
for i := 0; i < b.N; i++ {
    w.Write([]byte("Hello world"))
}

// GOOD — convert once
data := []byte("Hello world")
for i := 0; i < b.N; i++ {
    w.Write(data)
}
```

## Specify Container Capacity

```go
// Maps — capacity is a hint (not guaranteed preallocation)
m := make(map[string]os.DirEntry, len(files))

// Slices — capacity IS guaranteed preallocation; zero subsequent allocs until full
data := make([]int, 0, size)
for k := 0; k < size; k++ {
    data = append(data, k)
}
```
