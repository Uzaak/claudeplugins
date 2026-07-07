---
name: golang-standards
description: Use when starting, extending, or reviewing any Go service. Covers project layout, gin setup, logrus logging, envconfig, domain module structure, middleware stack, security headers, Swagger, HTTP client, Docker, CI/CD, and naming conventions.
---

# Golang Standards

## Overview

Go services follow the golang-style skill as a baseline, with specific choices for HTTP framework, logging, config, module structure, observability, and deployment. Apply these without deviation.

Code examples for every rule below: [references/code-examples.md](references/code-examples.md).

## Non-Negotiables

- Middleware stack in this exact order: Recovery → SecurityHeaders → Access(logging) → TracingHeaders → Prometheus.
- Security headers are mandatory on all responses (list below).
- **Never log secrets or PII.** Log at adapters and top-level; prefer Debug in services. Always `logrus.WithContext(ctx)` for trace propagation; JSON formatter set globally.
- `context.Context` as first parameter on all public functions doing I/O; never store context in struct fields; propagate trace headers via context.
- Validate required config at startup — fail fast with a clear message. All env vars in a single struct at `/configs/envs.go` using `kelseyhightower/envconfig`.
- Every handler must have Swagger godoc comments. Generate with `swag init -o api`; expose at `/swagger/index.html`.
- Expose at minimum `/health-check/liveness` (process alive) and `/health-check/readiness` (external integrations healthy).
- Never commit credentials or tokens — use `<access_key>` placeholders. Run security scanners in CI. Use prepared statements for SQL. Validate all inputs at the adapter/controller layer.

## Project Layout

```text
/cmd          — Main applications, CLI commands (cobra-cli)
/internal     — Private domain modules
/pkg          — Public reusable packages
/configs      — Environment config structs
/api          — Swagger/OpenAPI output
/deployments  — DevSpace, Kubernetes configs
```

## Domain Module Structure

Each domain in `/internal` must have all of these files:

| File | Purpose |
|---|---|
| `bootstrap.go` | Register routes with `*gin.Engine` |
| `controller.go` | HTTP handlers — thin layer only |
| `service.go` | Business logic |
| `structs.go` | Request/response types |
| `*_test.go` | Unit tests for each file |

## Gin Configuration

`gin.SetMode(gin.ReleaseMode)` in production; `gin.New()` (not Default); `HandleMethodNotAllowed = true`; set `NoRoute` and `NoMethod` handlers returning JSON.

## Middleware Stack (this exact order)

```go
router.Use(gin.Recovery())                // 1. panic recovery
router.Use(SecurityHeadersMiddleware())   // 2. security headers
router.Use(AccessMiddleware())            // 3. request logging
router.Use(TracingHeadersMiddleware())    // 4. distributed tracing
router.Use(PrometheusMiddleware())        // 5. metrics
```

## Security Headers (mandatory on all responses)

```text
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: no-referrer
```

## HTTP Client

Reusable `MakeRequest` utility in `/pkg/utils`: global timeout via `DEFAULT_HTTP_TIMEOUT` env; propagate context and trace headers automatically; use `http.Client` with timeout.

## Docker

Multi-stage build: `base` (tools) → `ci` (tests, swagger) → `builder` (`go build` with `CGO_ENABLED=0`) → `scratch` (binary only).

## CI/CD

- `feature/*`, `hotfix/*` → run tests only
- `release/*` → deploy to staging (requires approval)
- `master/main` → promote to production (requires approval)
- Required jobs: `unit-test`, static analysis, security scan
- Multi-arch builds: `arm64 + amd64`

## Cobra CLI Commands

Default `entrypoint` starts the HTTP server; `entrypoint routes` lists all routes; add commands with `cobra-cli add [name]`.

## Naming Conventions

| Element | Convention |
|---|---|
| Packages | lowercase, single word |
| Files | snake_case |
| Functions | camelCase (exported: PascalCase) |
| Constants | PascalCase or UPPER_SNAKE_CASE |
| Interfaces | `-er` suffix (Handler, Reader, Storer) |
