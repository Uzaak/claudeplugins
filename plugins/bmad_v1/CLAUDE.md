# BMAD v6 Multi-Agent Coding Pipeline

## What this project is
A 9-agent pipeline that takes a task description through planning → implementation → QA → verdict, producing production-ready code. Built for use via the Claude API with an HTML dashboard UI.

## Pipeline flow (always this order)
```
PLANNING:  Mary(Analyst) → John(PM) → Winston(Architect) → Bob(ScrumMaster)
IMPL:      Amelia(Coder) → Quinn(QA) → Reviewer → StressTester → Verdict
```

## Agent roster (load only what you need)

| File | Persona | Input → Output |
|------|---------|----------------|
| `agents/bmad-analyst.md` | Mary | Task → `product-brief.md` |
| `agents/bmad-pm.md` | John | Brief → `PRD.md` |
| `agents/bmad-architect.md` | Winston | PRD → `architecture.md` |
| `agents/scrum-master.md` | Bob | Arch+PRD → `story-{slug}.md` |
| `agents/coder.md` | Amelia | Story+Arch → Code |
| `agents/qa.md` | Quinn | Code+Story → Tests |
| `agents/reviewer.md` | — | Code → Review score (X/10) |
| `agents/stress.md` | — | Code+Tests → Stress score (X/10) |
| `agents/verdict.md` | — | All scores → PRODUCTION READY / NOT READY / READY WITH CONDITIONS |

> `agents/bmad/analyst.md`, `agents/bmad/architect.md`, `agents/bmad/pm.md` are legacy duplicates — deleted. Use root-level files only.

## Reference files (load on demand)

| File | When to load |
|------|--------------|
| `references/api-integration.md` | Building API call sequence or debugging fetch calls |
| `references/bmad-artifacts.md` | Verifying artifact schema or handoff contracts |
| `references/output-format.md` | Rendering pipeline output to user |
| `references/presets.md` | User asks for example tasks or presets |

## Skills
- `skills/multi-agent-coding-pipeline.md` — invoke with `/multi-agent-coding-pipeline <task>`

## Do NOT load automatically
- `assets/pipeline-ui.html` — ~11k tokens, HTML dashboard; read only if user asks about the UI

## Scoring thresholds
- PRODUCTION READY: overall ≥ 8.0, no CRITICAL issues (weighted: review 35%, stress 35%, QA 30%)
- READY WITH CONDITIONS: 6.5–7.9 overall, or ≥8.0 with 1 CRITICAL
- NOT READY: < 6.5 or unmitigated CRITICAL security issue

## Token budget per agent
| Agent | ~Input | ~Output |
|-------|--------|---------|
| Analyst | 200 | 400 |
| PM | 700 | 600 |
| Architect | 1 400 | 700 |
| Scrum Master | 2 200 | 500 |
| Coder | 1 000 | 900 |
| QA | 1 500 | 900 |
| Reviewer | 1 200 | 600 |
| Stress | 2 000 | 600 |
| Verdict | 2 500 | 700 |

If inputs exceed context: summarize earlier artifacts rather than passing full text.
Priority order to preserve: Story > Code > Review > Stress > earlier planning docs.

## Conventions
- TypeScript-first; full type annotations, no `any`, no untyped `dict`
- Tests: Jest (JS/TS), pytest (Python), `go test` + testify (Go)
- All agent outputs use structured markdown sections with headers
- Coder receives `story-{slug}.md` + `architecture.md` as primary inputs (not the raw task)
- Artifacts pass **full text**, never summaries, between agents

---

## Go Development Standards

When any agent produces or reviews Go code, these rules are **mandatory** and override generic guidance.

### Style authority (in priority order)
1. [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md) — primary reference for formatting, naming, error handling, and API design
2. [ardanlabs/gotraining](https://github.com/ardanlabs/gotraining) — design philosophy, mechanical sympathy, idiomatic patterns (Bill Kennedy / Ardan Labs)
3. [ardanlabs/service](https://github.com/ardanlabs/service) — production service layout, middleware, configuration, observability
4. Official [Effective Go](https://go.dev/doc/effective_go) and [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)

### Code rules (non-negotiable)
- Handle **every** error explicitly — no `_` discards on error returns unless justified with a comment
- Wrap errors with context: `fmt.Errorf("doing X: %w", err)` — never bare `return err`
- Use `errors.Is` / `errors.As` for inspection, never string matching
- No naked returns; no `init()` unless truly unavoidable
- Interfaces belong in the **consumer** package, not the provider
- Interface names: single-method → `<Verb>er` (e.g. `Reader`, `Storer`)
- Avoid embedding types in exported structs (breaks API stability)
- Reduce variable scope: declare variables close to first use
- `panic` only for unrecoverable programmer errors (never in library code)
- Package names: lowercase, single word, no underscores, no `utils`/`helpers`/`common`
- Context (`context.Context`) is always the **first** parameter, named `ctx`
- Goroutines must have a documented owner responsible for their lifecycle
- Use `sync.WaitGroup` + `errgroup` (golang.org/x/sync) for concurrent fan-out

### Project layout
Follow [ardanlabs/service](https://github.com/ardanlabs/service) conventions:
```
cmd/          — main packages only; no business logic
internal/     — private app packages (domain, data, web layers)
foundation/   — reusable cross-cutting concerns (logger, web, validate)
business/     — domain logic, use cases, data access interfaces
```
Avoid flat structures; group by domain, not by technical layer.

### Testing requirements (Go)
**Minimum 85% line coverage** — enforced by the QA agent and Reviewer agent.

| Test type | Tool | Requirement |
|-----------|------|-------------|
| Unit | `go test` + `testify/assert` | Every exported function; table-driven |
| Integration | `go test -tags=integration` | Full request → response; real DB or `dockertest` |
| Error paths | testify `require.Error` / `assert.ErrorIs` | Every `return err` path |
| Race detection | `go test -race ./...` | Must pass with zero races |

**Table-driven tests are the default pattern:**
```go
func TestFoo(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    string
        wantErr bool
    }{
        {"happy path", "valid", "ok", false},
        {"empty input", "", "", true},
    }
    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            got, err := Foo(tc.input)
            if tc.wantErr {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            assert.Equal(t, tc.want, got)
        })
    }
}
```

**Coverage enforcement commands (QA agent must run these):**
```bash
go test -coverprofile=coverage.out -covermode=atomic ./...
go tool cover -func=coverage.out | tail -1   # total must be ≥ 85%
go test -race ./...                          # must pass with 0 races
```

If coverage is below 85%, the QA agent MUST add tests before the artifact is passed to Reviewer. The Reviewer agent must fail (score ≤ 5) any Go submission under 85% coverage.

### Linting & static analysis
The Reviewer agent must check that these would pass (or note failures):
```bash
go vet ./...
staticcheck ./...     # honnef.co/go/tools
golangci-lint run     # uber-go/golangci-lint config
```
Zero `go vet` errors is a hard requirement. `staticcheck` warnings are scored as MEDIUM issues.

### Dependency policy
- Standard library first; only add third-party deps for genuine gaps
- Prefer well-maintained packages from the `ardanlabs` or `uber-go` ecosystem where available
- No `github.com/pkg/errors` (use stdlib `errors` + `fmt.Errorf("%w", ...)`)
- Approved common deps: `go.uber.org/zap`, `github.com/testify/testify`, `golang.org/x/sync`, `github.com/ardanlabs/conf/v3`
