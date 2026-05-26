---
name: deprecated_analyse_architecture
description: Use when the user runs /analyse_architecture — deeply inspects the project structure, dependencies, and libraries via Serena and DataDog, then writes Architecture.md, updates root CLAUDE.md, and writes per-subdirectory CLAUDE.md files.
argument-hint: [project-directory]
---

# uzaak: Analyse Architecture

Produce a comprehensive `Architecture.md` documenting the project's structure, technology choices, and design patterns — combining static analysis (via Serena) with live DataDog service topology. Then propagate that knowledge into `CLAUDE.md` files throughout the project.

---

## Step 0 — Determine project directory

If an argument was provided, use it as the project directory. Otherwise use the current working directory.

Infer the application name from the project directory name (last path segment).

Print: `[<project>] Starting architecture analysis...`

---

## Step 1 — Check Serena availability (optional)

Serena is **optional**. Determine whether it is available by attempting to call `mcp__serena__check_onboarding_performed`.

- If the tool **does not exist or returns an error** → set `serena_available = false`. Print: `[<project>] Serena: not configured — will use file-based inspection`
- If the tool **exists and onboarding is already done** → set `serena_available = true`. Print: `[<project>] Serena: ready`
- If the tool **exists but onboarding has not been run** → run `mcp__serena__onboarding` now, then set `serena_available = true`. Print: `[<project>] Serena: onboarding completed`

---

## Step 2 — Detect stack and top-level structure

### 2a — Stack detection

Detect the primary tech stack (first match wins):

| File present | Stack |
|---|---|
| `go.mod` | go |
| `package.json` | node |
| `composer.json` | php |
| `requirements.txt` or `pyproject.toml` | python |
| `Gemfile` | ruby |
| (none) | unknown |

Record the stack as `primary_stack`.

### 2b — Top-level directory inventory

List all entries in the project root. Collect:
- **Immediate subdirectories** that do **not** start with `.` → record as `subdirs[]`
- **Key root files** (configuration, manifests, entrypoints): e.g. `main.go`, `index.js`, `app.py`, `Dockerfile`, `docker-compose.yml`, `Makefile`, `.env.example`, CI/CD files (`*.yml` under `.github/`, `Jenkinsfile`, etc.)

Print: `[<project>] Top-level directories: <subdirs joined by ", ">`
Print: `[<project>] Key root files: <files joined by ", ">`

---

## Step 3 — Deep project analysis

### 3a — Dependency file analysis

Parse the primary dependency file for the detected stack:

| Stack | File | What to extract |
|---|---|---|
| go | `go.mod` | module name, Go version, all `require` entries (direct + indirect) |
| node | `package.json` | name, version, `dependencies`, `devDependencies`, `scripts` |
| php | `composer.json` | name, `require`, `require-dev` |
| python | `requirements.txt` / `pyproject.toml` | all package pins; for pyproject.toml also extract `[tool.poetry.dependencies]` or `[project.dependencies]` |
| ruby | `Gemfile` | all `gem` declarations |

From the extracted list, identify **notable libraries** — frameworks, ORMs, HTTP clients, auth libraries, observability packages — and record them with a brief one-line description of their role (inferred from the library name or widely-known purpose).

Record as `dependencies[]` = `{ name, version, role }`.

### 3b — Entry points and main application files

Locate the primary entry point(s):

- **Go**: `main.go` at root or inside `cmd/*/main.go`
- **Node**: the `main` field in `package.json`, or `index.js` / `server.js` / `app.js`
- **PHP**: `public/index.php`, `artisan` (Laravel), `bin/console` (Symfony)
- **Python**: `manage.py` (Django), `app.py`, `main.py`, `wsgi.py`, `asgi.py`
- **Ruby**: `config.ru`, `bin/rails`

Use Serena's `mcp__serena__get_symbols_overview` on each entry point (if `serena_available = true`), or read the file directly otherwise. Extract:
- How the application is bootstrapped
- Which framework/router is initialized
- Top-level middleware or configuration loaded at startup

### 3c — Architectural pattern detection

Examine the directory names in `subdirs[]` and the files within them (list one level deep) to identify the architectural style:

| Pattern | Indicators |
|---|---|
| MVC | dirs named `controllers/`, `models/`, `views/` |
| Hexagonal / Clean | dirs named `domain/`, `application/`, `infrastructure/`, `adapters/`, `ports/` |
| DDD modules | multiple dirs each containing their own `domain/` or `repository/` sub-dirs |
| Layered | dirs named `handlers/`, `services/`, `repositories/` |
| Feature-based | dirs named after business features (e.g. `orders/`, `users/`, `payments/`) |
| Monolith vs. microservice | single `main.go`/`main.py` vs. multiple `cmd/*/` or `services/*/` |

Record detected pattern(s) as `arch_patterns[]`.

### 3d — Per-subdirectory purpose inference

For each directory in `subdirs[]`:

1. List its immediate contents (files + subdirs, one level deep).
2. If `serena_available = true`, call `mcp__serena__get_symbols_overview` on representative files within it.
3. Infer the directory's purpose from its name, contents, and any symbols found.

Record as `subdir_map[]` = `{ dir, purpose, key_files[], key_symbols[] }`.

### 3e — Configuration and environment discovery

Locate configuration sources:
- Environment variable files: `.env`, `.env.example`, `.env.sample`
- Config files: `config/`, `configs/`, `settings.py`, `config.go`, `*.yaml`/`*.yml` not in CI dirs
- Feature flags or external config systems referenced in code (e.g. `os.Getenv`, `process.env`, `viper`, `envconfig`)

Record `config_sources[]` = `{ source_type, file_or_pattern, notes }`.

### 3f — Test structure discovery

Locate test files and frameworks:

| Stack | Test indicators |
|---|---|
| go | `*_test.go` files; detect `testify`, `gomock`, `ginkgo` in `go.mod` |
| node | `*.spec.*`, `*.test.*`; detect `jest`, `mocha`, `vitest` in `package.json` |
| php | `tests/` dir, `phpunit.xml` |
| python | `tests/` dir, `conftest.py`, `pytest.ini` |
| ruby | `spec/` dir, `.rspec` |

Record `test_framework` and `test_dirs[]`.

---

## Step 4 — DataDog service topology (optional)

Skip this step entirely if DataDog tools are unavailable (i.e., `mcp__datadog__search_datadog_services` does not exist).

### 4a — Locate the service in DataDog

Query `mcp__datadog__search_datadog_services` using `name:<project>*`.

- No results → set `dd_services = []`, print `[<project>] DataDog: no services found — skipping topology`
- Results found → filter for production/live variants (prefer `.live`, `prod`; discard `.qa`, `.staging`, `.svc.cluster.local`)

For each candidate, validate with a span count query:
```
mcp__datadog__aggregate_spans  service:<name>  COUNT *  from: now-30d  to: now
```
Keep only services with count > 0.

Record surviving services as `dd_services[]`.

### 4b — Infer topology from DataDog spans

For each service in `dd_services[]`, run the following queries (last 30 days):

**Downstream HTTP dependencies** (services this app calls):
```
mcp__datadog__aggregate_spans  service:<name>  span.kind:client  http.url:*
  COUNT *  group by peer.service
  from: now-30d  to: now
```
If `span.kind:client` returns empty, retry without the filter.

**Downstream gRPC dependencies**:
```
mcp__datadog__aggregate_spans  service:<name>  span.kind:client  rpc.system:grpc
  COUNT *  group by rpc.service
  from: now-30d  to: now
```

**Downstream database dependencies**:
```
mcp__datadog__aggregate_spans  service:<name>  span.kind:client  db.system:*
  COUNT *  group by db.system, db.name
  from: now-30d  to: now
```
Exclude redis/memcached here (handled separately as caches).

**Cache dependencies**:
```
mcp__datadog__aggregate_spans  service:<name>  span.kind:client  db.system:(redis OR memcached OR elasticache)
  COUNT *  group by db.system, peer.hostname
  from: now-30d  to: now
```

Record `dd_topology` = `{ http_deps[], grpc_deps[], db_deps[], cache_deps[] }`.

Cross-reference `dd_topology` against the codebase-derived `dependencies[]` and `outbound` call sites found in Step 3 to enrich descriptions.

Print: `[<project>] DataDog topology: <N> HTTP deps, <N> gRPC deps, <N> DB deps, <N> cache deps`

---

## Step 5 — Rotate existing architecture file

Before writing the new report, apply this rotation logic in order:

1. If `<project-dir>/Architecture_old.md` exists → **delete** it.
2. If `<project-dir>/Architecture.md` exists → **rename/move** it to `Architecture_old.md`.
3. Proceed to write the new `Architecture.md`.

---

## Step 6 — Write Architecture.md

Create `<project-dir>/Architecture.md` with the following structure:

```markdown
# Architecture — <project-name>

> Generated: <YYYY-MM-DD HH:MM:SS UTC>
> Stack: <primary_stack>
> Pattern(s): <arch_patterns joined by ", ">

## Overview

<2–4 sentence narrative describing what this application does, its primary role (API server / worker / CLI / frontend / library), and its position in the wider system. Infer from entry points, route definitions, README if present, and DataDog service names.>

## Technology Stack

| Category | Choice | Notes |
|---|---|---|
| Language | <language + version> | e.g. Go 1.22, Node 20, Python 3.12 |
| Framework | <framework> | e.g. Gin, Express, Django |
| ORM / DB client | <library or "none"> | |
| HTTP client | <library or "none"> | |
| Auth | <library or "none"> | |
| Observability | <library or "none"> | e.g. DataDog APM, Prometheus |
| Testing | <framework(s)> | |
| Config / Env | <approach> | e.g. envconfig, dotenv, viper |

## Project Structure

<List each top-level subdirectory with a one-line description of its purpose. Ignore hidden directories.>

```
<project>/
├── <dir1>/          # <purpose>
├── <dir2>/          # <purpose>
...
```

## Key Dependencies

List all notable runtime dependencies with their inferred role:

| Package | Version | Role |
|---|---|---|
| <name> | <version> | <role> |
...

## Architecture Pattern

<1–3 paragraphs explaining the architectural style (MVC, Hexagonal, DDD, layered, etc.) with specific examples from the codebase: which dir maps to which layer, where the domain logic lives, how external dependencies are abstracted.>

## Configuration

<Describe how the application is configured: environment variables, config files, external config systems. List key env vars if discoverable from .env.example or config structs.>

## Testing

<Describe the testing approach: framework, test locations, coverage tooling, any notable patterns like table-driven tests, integration test setup, mocking strategy.>

## Data Stores & External Dependencies

<Describe all databases, caches, external HTTP APIs, and gRPC services the application integrates with. For each, note: system type, purpose, and whether it was confirmed via static analysis, DataDog, or both.>

### Databases

| System | Database/Schema | Purpose | Source |
|---|---|---|---|
| <system> | <name> | <purpose> | code / DataDog / both |

### Caches

| System | Host | Purpose | Source |
|---|---|---|---|

### External Services

| Destination | Protocol | Purpose | Source |
|---|---|---|---|

## DataDog Service Topology

<Skip this section entirely if DataDog returned no data.>

DataDog service(s): `<dd_services joined by ", ">`

<Describe what the DataDog trace topology revealed about runtime behaviour that supplements the static analysis — e.g. call volumes, services that appear in runtime but are not obvious from the code.>

## Architectural Highlights & Notes

<Bullet list of anything notable: unusual patterns, technical debt indicators, performance-sensitive paths, security boundaries, multi-tenancy, internationalization, multi-country deployment, etc.>
```

**Formatting rules:**
- Omit any section that has no content (e.g. omit "DataDog Service Topology" if DataDog was unavailable).
- Always include the "Generated" timestamp header — future runs will rotate and replace this file.
- Keep the Overview narrative factual and terse; avoid marketing language.

---

## Step 7 — Update root CLAUDE.md

Check whether `<project-dir>/CLAUDE.md` exists.

**Does not exist** → create it with:

```markdown
# Project: <project-name>

## Architecture Reference

See [Architecture.md](./Architecture.md) for the full architectural overview of this project, including technology stack, project structure, key dependencies, and data store topology.
Always consult this file before making architectural decisions or when uncertain about the intended structure of the codebase.
```

**Exists, does NOT mention `Architecture.md`** → append at the end:

```markdown

## Architecture Reference

See [Architecture.md](./Architecture.md) for the full architectural overview of this project, including technology stack, project structure, key dependencies, and data store topology.
Always consult this file before making architectural decisions or when uncertain about the intended structure of the codebase.
```

**Exists and already mentions `Architecture.md`** → update only the reference block (lines between `## Architecture Reference` and the next `##` heading, or end of file) to point correctly. Leave all other content unchanged.

Print: `[<project>] Root CLAUDE.md updated`

---

## Step 8 — Write per-subdirectory CLAUDE.md files

For each directory in `subdirs[]` (depth = 1, no hidden directories):

### 8a — Read existing CLAUDE.md (if any)

If `<subdir>/CLAUDE.md` already exists, read it in full. Record its existing content as `existing_content`.

### 8b — Compose the architecture block

Build an architecture description block for this directory:

```markdown
## Directory: <dir-name>

<purpose from subdir_map>

**Key files:**
<bullet list of key_files — omit if none found>

**Key symbols / components:**
<bullet list of key_symbols — omit if empty>
```

### 8c — Write or merge

**Does not exist** → write the block as the entire file content.

**Exists** → merge:
- If the file already contains a `## Directory: <dir-name>` section → replace that section with the new block, preserving all other sections verbatim.
- If it does not contain such a section → prepend the block before the existing content, separated by `---`.

The goal is that **no existing non-architecture instructions are lost**.

Print: `[<project>] CLAUDE.md written: <subdir>/CLAUDE.md`

---

## Step 9 — Summary

Always print this summary at the end:

```
╔══════════════════════════════════════════════════╗
║         Architecture Analysis Complete           ║
║  <project-name>                                  ║
╠══════════════════════════════════════════════════╣
║ Stack           : <primary_stack>                ║
║ Pattern(s)      : <arch_patterns>                ║
║ Dependencies    : <N> notable packages           ║
╠══════════════════════════════════════════════════╣
║ DataDog         : <found N services / not found> ║
║   HTTP deps     : <N>                            ║
║   gRPC deps     : <N>                            ║
║   DB deps       : <N>                            ║
║   Cache deps    : <N>                            ║
╠══════════════════════════════════════════════════╣
║ Files written                                    ║
║   Architecture.md      : <project-dir>           ║
║   Previous arch saved  : Architecture_old.md / none ║
║   Root CLAUDE.md       : updated / created       ║
║   Sub CLAUDE.md(s)     : <N> files written       ║
╠══════════════════════════════════════════════════╣
║ Generated       : <YYYY-MM-DD HH:MM UTC>         ║
╚══════════════════════════════════════════════════╝
```

---

## Key rules

- **Never modify source code or tests.** This skill is read-only with respect to application code.
- **Always rotate Architecture.md.** Never overwrite directly — always follow the rotation sequence in Step 5 (`Architecture.md` → `Architecture_old.md`).
- **Never lose existing CLAUDE.md instructions.** When merging into an existing CLAUDE.md (root or subdirectory), preserve all content not related to the architecture block. Merge, do not overwrite blindly.
- **Ignore hidden directories.** Do not create CLAUDE.md files for directories whose names start with `.`.
- **DataDog is optional.** If unavailable or returning no data, complete the analysis from static inspection alone. Do not fail or block.
- **Serena is optional.** If its MCP server is not configured, fall back to direct file inspection — never fail because Serena is absent.
- **Always write the timestamp.** Architecture.md must record exactly when it was generated.
- **Always update root CLAUDE.md.** Even if Architecture.md has minimal content, the reference must be present.
- **Infer, don't invent.** All statements in Architecture.md must be grounded in evidence from the codebase or DataDog. Mark uncertain inferences with *(inferred)*.
