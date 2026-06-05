---
name: generate-internal-architecture-md
description: Use when the user runs /generate-internal-architecture-md — reads the project's structure, frameworks, coding patterns, entry points, test suites, build instructions, environment variables, and observability instrumentation to produce an architecture/Internal.md that helps developers contribute high-quality code to the project.
argument-hint: [project-directory]
---

# uzaak: Generate Internal Architecture

Produce a developer-focused `architecture/Internal.md` that answers: **how is this system built and how do I work with it?** Document the directory structure and what belongs where, how to build and run the project, how tests are organised and executed, what coding patterns are in use, what every environment variable does, and what observability is in place. Do NOT document data persistence, caching, or external service integrations — that is `External.md`'s job.

Print: `[<project>] Starting internal architecture analysis...`

---

## Step 0 — Determine project directory

If an argument was provided, use it as the project directory. Otherwise use the current working directory.

Infer the application name from the project directory name (last path segment).

---

## Step 1 — Detect stack, languages, and frameworks

### 1a — Primary stack detection

Detect the primary tech stack (first match wins):

| File present | Stack |
|---|---|
| `go.mod` | go |
| `package.json` | node |
| `composer.json` | php |
| `requirements.txt` or `pyproject.toml` | python |
| `Gemfile` | ruby |
| (none) | unknown |

Read the dependency file to extract the **language version** (`go` directive in `go.mod`, `engines.node` in `package.json`, `python_requires` in `pyproject.toml`, etc.).

### 1b — Framework detection

Scan the dependency file for web/application frameworks:

| Stack | Frameworks to detect |
|---|---|
| **go** | `gin-gonic/gin`, `labstack/echo`, `gofiber/fiber`, `gorilla/mux`, `go-chi/chi`, `grpc` |
| **node** | `express`, `fastify`, `nestjs/core`, `koa`, `hapi`, `@trpc/server` |
| **php** | `laravel/framework`, `symfony/symfony`, `slim/slim`, `yiisoft/yii2` |
| **python** | `fastapi`, `flask`, `django`, `starlette`, `sanic`, `tornado` |
| **ruby** | `rails`, `sinatra`, `grape`, `hanami` |

Also detect notable supporting libraries: ORMs, job queues, CLI frameworks, GraphQL libraries, gRPC, etc.

Record `stack` = `{ language, version, primary_framework, notable_libraries[] }`.

Print: `[<project>] Stack: <language> <version> / <primary_framework>`

---

## Step 2 — Directory structure analysis

List the top-level directories and any second-level directories that are significant (contain source code, config, scripts, or tests). Skip generated directories (`vendor/`, `node_modules/`, `.git/`, `dist/`, `build/`, `__pycache__/`).

For each directory, infer its purpose from its name and contents:

| Common name | Typical purpose |
|---|---|
| `cmd/`, `bin/`, `entrypoints/` | Application entry points |
| `internal/`, `src/`, `app/`, `lib/` | Core application source |
| `pkg/`, `shared/`, `common/` | Shared/reusable packages |
| `api/`, `routes/`, `handlers/`, `controllers/` | HTTP layer |
| `services/`, `usecases/`, `domain/` | Business logic |
| `repositories/`, `store/`, `dao/` | Data access layer |
| `middleware/` | Request/response middleware |
| `config/`, `configs/` | Configuration loading |
| `scripts/`, `tools/`, `hack/` | Developer tooling |
| `migrations/`, `db/` | Database schema management |
| `proto/`, `grpc/` | Protobuf definitions |
| `static/`, `public/`, `assets/` | Static assets |
| `docs/`, `documentation/` | Documentation |
| `deploy/`, `infra/`, `k8s/`, `helm/` | Deployment configuration |
| `.github/` | CI/CD workflows |

Read a sample of files in ambiguous directories to confirm the purpose before describing it.

Record `directories[]` = `{ path, purpose, notable_files[] }`.

Print: `[<project>] Mapped <N> significant directories`

---

## Step 3 — Test infrastructure analysis

Find all directories that contain tests. Search for:

- Standard test directories: `tests/`, `test/`, `spec/`, `__tests__/`
- Specialised directories: `integration/`, `e2e/`, `stress/`, `load/`, `contract/`, `functional/`, `acceptance/`
- Test files co-located with source: `*_test.go`, `*.test.ts`, `*.spec.js`, `test_*.py`, `*_spec.rb`
- Test configuration files: `jest.config.*`, `pytest.ini`, `.rspec`, `vitest.config.*`, `cypress.config.*`, `k6*.js`

For each test suite found, determine:
- **Type**: unit, integration, e2e, stress/load, contract, benchmark
- **Framework**: Jest, Pytest, Go testing, RSpec, Cypress, k6, Gatling, etc.
- **Scope**: what part of the system it tests (infer from directory name and a sample of test files)
- **Run command**: see Step 4 for how to extract this

Record `test_suites[]` = `{ path, type, framework, scope, run_command }`.

Print: `[<project>] Found <N> test suites: <types joined by ", ">`

---

## Step 4 — Build and run instructions

### 4a — Makefile / task runner

Read `Makefile`, `Taskfile.yml`, `justfile`, or `scripts/` to extract named targets related to building, running, and testing.

Capture targets whose names suggest: `build`, `run`, `start`, `dev`, `test`, `lint`, `generate`, `migrate`, `docker`, `compose`.

### 4b — Local run

Determine how to run the application locally without Docker:

| Stack | Where to look |
|---|---|
| **go** | `go run ./cmd/...` or `go build -o bin/<name> && ./bin/<name>`; check `main.go` location |
| **node** | `scripts.start` / `scripts.dev` in `package.json` |
| **php** | `php artisan serve` / `composer run start` |
| **python** | `uvicorn`, `gunicorn`, `flask run`, `python -m <module>` — check `pyproject.toml` scripts or README |
| **ruby** | `rails server` / `bundle exec rackup` / `foreman start` |

### 4c — Docker / docker-compose run

Check for:
- `docker-compose.yml`, `docker-compose.yaml`, `compose.yml`
- `Dockerfile`, `Dockerfile.dev`

Extract the primary `app` service and note the run command, exposed ports, and any prerequisite services (databases, caches) that must be started alongside it.

Document: `docker compose up app` vs `docker compose up` if multiple services are required.

### 4d — Test run commands

For each test suite identified in Step 3, record the exact command to run it:

| Stack | Unit tests | Integration | Other |
|---|---|---|---|
| **go** | `go test ./...` | `go test ./integration/...` | `go test -run Benchmark ./...` |
| **node/jest** | `npx jest` | `npx jest --testPathPattern=integration` | `npx jest --testPathPattern=e2e` |
| **python** | `pytest` | `pytest tests/integration/` | `pytest tests/stress/` |
| **ruby** | `bundle exec rspec` | `bundle exec rspec spec/integration/` | — |

If a Makefile target exists (e.g. `make test-integration`), prefer that.

Record `run_instructions` = `{ local_build, local_run, docker_run, test_commands[] }`.

Print: `[<project>] Documented build/run/test instructions`

---

## Step 5 — Coding patterns and architecture

### 5a — Entry points

Locate and read the application entry point(s):

- **go**: files containing `func main()` — typically `cmd/<name>/main.go` or `main.go`
- **node**: `main` field in `package.json`, or `index.js`, `server.js`, `app.js`
- **python**: `if __name__ == "__main__"` blocks, `app.py`, `manage.py`, `__main__.py`
- **php**: `public/index.php`, `artisan`
- **ruby**: `config.ru`, `bin/rails`

From each entry point, trace what gets initialised: config loading order, dependency injection setup, middleware registration, router mounting, server start.

### 5b — Request/response flow

Trace a representative request through the stack. Read the router file and one handler end-to-end:
- How is routing defined (file-based, decorator-based, explicit registration)?
- What middleware runs on all requests (auth, logging, tracing, rate limiting)?
- How does a handler receive its dependencies (DI container, constructor injection, globals, closures)?
- What does a typical successful response look like?
- How are errors returned (custom error types, HTTP status mapping, error middleware)?

### 5c — Layer responsibilities

Identify the architectural layers present and what each is responsible for. Common patterns:

| Pattern | Layers |
|---|---|
| **MVC** | Controllers (HTTP), Models (data), Views (templates) |
| **Layered / Clean** | Handlers → Services → Repositories → DB |
| **Hexagonal** | Adapters (in/out) → Ports → Domain |
| **CQRS** | Commands, Queries, Handlers, Projections |

For each layer found, describe: what it does, what it receives, what it returns, what it must NOT do (e.g. "repositories must not contain business logic").

### 5d — Error handling conventions

Read how errors propagate:
- Are custom error types defined? What fields do they carry (code, message, HTTP status)?
- Is error wrapping used (`fmt.Errorf("%w", err)`, `errors.Wrap`)?
- Where are errors logged vs returned vs translated to HTTP responses?
- Are panics recovered? Where?

### 5e — Expected outputs and contracts

Identify what the application produces:
- HTTP response format (JSON envelope, plain body, gRPC message)
- Standard response envelope fields (e.g. `{ data, error, meta }`)
- Pagination convention (cursor-based, offset, page/size)
- Error response format (`{ code, message, details }`)

Record `architecture` = `{ entry_points[], layers[], request_flow, error_handling, output_contracts }`.

Print: `[<project>] Analysed coding patterns and architecture`

---

## Step 6 — Environment variables

Find all environment variable reads in the codebase:

- **go**: `os.Getenv(`, `os.LookupEnv(`, `viper.Get(`, `envconfig.Process(`
- **node**: `process.env.`, `dotenv`, `env(` from config libraries
- **python**: `os.environ[`, `os.getenv(`, `environ.get(`, `settings.<VAR>`
- **php**: `env(`, `$_ENV[`, `getenv(`
- **ruby**: `ENV[`, `ENV.fetch(`

Also read `.env.example`, `.env.sample`, `.env.test`, and any `config/` files that map env vars to application settings.

For each variable, record:
- **Name**: the env var key
- **Required / Optional**: required if no default or if `LookupEnv` checks for presence; optional if a default is provided
- **Purpose**: infer from variable name and the code that uses it (e.g. `DATABASE_URL` → primary DB connection string; `FEATURE_FLAG_NEW_CHECKOUT` → toggles new checkout flow)
- **Example value**: from `.env.example` if present

Record `env_vars[]` = `{ name, required, purpose, example }`.

Print: `[<project>] Found <N> environment variables`

---

## Step 7 — Observability and metrics

Search the dependency file and source code for observability instrumentation:

### 7a — Detect libraries

| Library | Detection |
|---|---|
| **Prometheus** | `prometheus/client_golang`, `prom-client`, `prometheus_client` |
| **OpenTelemetry** | `go.opentelemetry.io`, `@opentelemetry/sdk-*`, `opentelemetry-sdk` |
| **Datadog** | `DataDog/dd-trace-go`, `dd-trace-js`, `ddtrace` |
| **New Relic** | `newrelic/go-agent`, `newrelic`, `newrelic-python-agent` |
| **Instana** | `instana/go-sensor`, `@instana/collector` |
| **Grafana / Loki** | `grafana/loki`, `loki-logrus` |
| **Sentry** | `getsentry/sentry-go`, `@sentry/node`, `sentry-sdk` |
| **Jaeger / Zipkin** | `jaegertracing`, `openzipkin` |
| **StatsD** | `alexcesaro/statsd`, `hot-shots`, `statsd` |

### 7b — Inventory what is instrumented

For each library found, scan the codebase to identify:

- **Metrics**: counter/gauge/histogram names and what they measure (e.g. `http_requests_total`, `order_processing_duration_seconds`)
- **Traces**: which operations are traced (HTTP handlers, DB queries, external calls), span names and attributes
- **Logs**: logging library (`zap`, `logrus`, `winston`, `structlog`), log levels used, structured fields present
- **Errors**: which error types or panic conditions are reported to which system
- **Custom events**: business events tracked (e.g. analytics events sent to GA or Segment)

Record `observability` = `{ libraries[], metrics[], traces[], logs, error_reporting[] }`.

Print: `[<project>] Found observability: <libraries joined by ", ">`

---

## Step 8 — Write Internal.md

Create the `<project-dir>/architecture/` directory if it does not exist, then write (overwriting if it already exists) `<project-dir>/architecture/Internal.md`:

```markdown
# Internal Architecture — <project-name>

> Generated: <YYYY-MM-DD HH:MM:SS UTC>
> Stack: <language> <version> / <primary_framework>

## Overview

<3–5 sentences. What type of application is this (HTTP API, background worker, CLI, monolith, microservice)? What is the primary framework? What is the overall architectural style? What are the main entry points? Infer from entry point files, route definitions, and README if present.>

## Tech Stack

| Layer | Technology | Version |
|---|---|---|
<One row per significant technology: language, framework, ORM, job queue, CLI library, test framework, etc.>

## Directory Structure

<A concise map of the project's directories. For each significant directory: its path, its purpose in one sentence, and any important files within it. Do NOT list every file — focus on directories and the most important files that define the project's shape.>

```
<project>/
├── <dir>/        — <purpose>
│   └── <notable-file>   — <what it does>
├── <dir>/        — <purpose>
...
```

## Entry Points

<For each entry point: file path, what it initialises, and in what order (config → DI → middleware → routes → server start). Be specific about the initialisation sequence — a developer setting up a new dependency needs to know where to wire it in.>

### `<entry-point-file>`

<2–4 sentences describing what this entry point boots and in what order.>

## Architectural Layers

<Describe each layer: its name, its responsibility, what it receives, what it returns, and — critically — what it must NOT do. Make boundaries explicit so developers know where new code belongs.>

### <Layer Name> (`<directory>`)

**Responsibility:** <one sentence>

**Receives:** <what comes in>

**Returns:** <what goes out>

**Must not:** <boundary violations to avoid>

<Repeat for each layer>

## Request / Response Flow

<Trace a representative request end-to-end. Name the actual files and functions involved. Describe what middleware runs, how the handler gets its dependencies, what a normal response looks like, and how an error propagates back to the caller. A developer reading this should be able to add a new endpoint without guessing.>

## Error Handling

<Describe the error handling convention: custom error types (with their fields), how errors are wrapped and propagated, where they are logged vs translated to HTTP responses, and how panics are recovered. Include a code-comment-style example if the convention is non-obvious.>

## Output Contracts

<Describe the shape of successful and error responses. Include the envelope structure, field names, and the pagination convention if present. A developer writing a new endpoint should be able to match the existing contract without reading other handlers.>

## Testing

<One sub-section per test suite. For each: what it tests, how to run it, and any setup required (env vars, running services, seed data).>

<For each test suite found in Step 3:>

### <Suite type> — `<path>`

**Framework:** <test framework>

**Scope:** <what this suite tests>

**Run:**
```bash
<exact command>
```

**Setup required:** <env vars, docker services, seed data — or "none">

## Building & Running

### Local

```bash
# Build
<build command>

# Run
<run command>
```

### Docker

```bash
# Run with docker compose
<docker compose command>
```

<Note any services that must be started alongside the app (DB, cache, etc.) and whether they are included in the compose file.>

## Environment Variables

| Variable | Required | Purpose | Example |
|---|---|---|---|
<One row per env var. Required = yes/no. Purpose: one sentence explaining what it controls. Example: from .env.example or a safe representative value.>

## Observability

<If no observability libraries found, write "No observability instrumentation detected." Otherwise, one sub-section per library.>

### <Library name>

**Type:** <metrics / tracing / logging / error reporting>

**What is instrumented:**
<Bullet list of what is tracked: metric names and what they count/measure, which operations are traced, what structured log fields are emitted, which error types are reported.>
```

**Formatting rules:**
- Every claim must be grounded in files actually read. Mark uncertain inferences with *(inferred)*.
- The Directory Structure section must use an ASCII tree — keep it readable, not exhaustive.
- The Environment Variables table must be complete — missing a required variable here means a developer's local setup will fail silently.
- Do NOT include data persistence, caching, or external service details — those belong in `External.md`.
- Keep the Overview factual; avoid marketing language.

---

## Step 9 — Summary

```
╔══════════════════════════════════════════════════╗
║     architecture/Internal.md Generated           ║
║  <project-name>                                  ║
╠══════════════════════════════════════════════════╣
║ Stack           : <language> / <framework>       ║
║ Directories     : <N> mapped                     ║
║ Test suites     : <N> (<types>)                  ║
║ Env variables   : <N>                            ║
║ Observability   : <libraries or "none">          ║
╠══════════════════════════════════════════════════╣
║ Generated       : <YYYY-MM-DD HH:MM UTC>         ║
╚══════════════════════════════════════════════════╝
```

---

## Key rules

- **Never modify source code, tests, migrations, or config files.** Read-only with respect to the project.
- **No data layer.** Do not document databases, caches, queues, or external services — that is `External.md`'s job.
- **Developer-first.** Every section must help a developer write code or run the project. If information does not serve that goal, omit it.
- **Complete env var table.** A missing required variable here costs a developer hours of debugging. Read every config file.
- **Evidence-based.** All claims must be traceable to a file you read. Mark inferences as *(inferred)*.
- **Exact commands.** Run commands must be copy-pasteable and correct. Test them against what you find in Makefiles, package.json scripts, and README snippets.
