---
name: golang-dafiti-standards
description: Use when starting, extending, or reviewing any Go service. Covers project layout, gin setup, logrus logging, envconfig, domain module structure, middleware stack, security headers, Swagger, HTTP client, Docker, CI/CD, and naming conventions.
---

# Golang Standards

## Overview

Go services follow the Uber Go style guide as a baseline, with specific choices for HTTP framework, logging, config, module structure, observability, and deployment. Apply these without deviation.

## Project Layout

```
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

```go
// bootstrap.go
func Bootstrap(router *gin.Engine) {
    group := router.Group("/orders")
    group.GET("/:id", GetOrder)
    group.POST("/", CreateOrder)
}

// controller.go
func GetOrder(ctx *gin.Context) {
    result, err := service.GetOrder(ctx.Request.Context(), ctx.Param("id"))
    if err != nil {
        ctx.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
        return
    }
    ctx.JSON(http.StatusOK, result)
}

// service.go
func GetOrder(ctx context.Context, id string) (Response, error) {
    logrus.WithContext(ctx).Debug("get order")
    // business logic
    return Response{}, nil
}
```

## Gin Configuration

```go
gin.SetMode(gin.ReleaseMode)       // production
router := gin.New()
router.HandleMethodNotAllowed = true
// Set NoRoute and NoMethod handlers returning JSON
router.NoRoute(func(c *gin.Context) {
    c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
})
```

## Middleware Stack (this exact order)

```go
router.Use(gin.Recovery())                // 1. panic recovery
router.Use(SecurityHeadersMiddleware())   // 2. security headers
router.Use(AccessMiddleware())            // 3. request logging
router.Use(TracingHeadersMiddleware())    // 4. distributed tracing
router.Use(PrometheusMiddleware())        // 5. metrics
```

## Security Headers (mandatory on all responses)

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: no-referrer
```

## Logging — logrus

```go
import "github.com/sirupsen/logrus"

// Always use WithContext for trace propagation
logrus.WithContext(ctx).Info("processing order")
logrus.WithContext(ctx).WithField("order_id", id).Debug("fetching order")

// Standard fields
// timestamp, message, caller — set JSON formatter globally
logrus.SetFormatter(&logrus.JSONFormatter{})
```

**Never log secrets or PII.** Log at adapters and top-level; prefer Debug in services.

## Configuration — envconfig

All environment variables in a single struct at `/configs/envs.go`:

```go
package configs

import "github.com/kelseyhightower/envconfig"

type Config struct {
    Port           int    `env:"PORT" default:"8080" json:"PORT"`
    DBHost         string `env:"DB_HOST" required:"true" json:"DB_HOST"`
    HttpTimeout    int    `env:"DEFAULT_HTTP_TIMEOUT" default:"30" json:"DEFAULT_HTTP_TIMEOUT"`
}

var Envs Config

func init() {
    if err := envconfig.Process("", &Envs); err != nil {
        log.Fatalf("config error: %v", err)
    }
}
```

Validate required config at startup — fail fast with clear message.

## Swagger Documentation

Every handler must have godoc comments:

```go
// GetOrder godoc
// @Summary      Get order by ID
// @Description  Returns a single order
// @Produce      json
// @Tags         orders
// @Param        id   path      string  true  "Order ID"
// @Success      200  {object}  OrderResponse
// @Failure      404  {object}  ErrorResponse
// @Router       /orders/{id} [get]
func GetOrder(ctx *gin.Context) { ... }
```

Generate with: `swag init -o api`
Expose at: `/swagger/index.html`

## HTTP Client

Reusable `MakeRequest` utility in `/pkg/utils`:
- Global timeout via `DEFAULT_HTTP_TIMEOUT` env
- Propagate context and trace headers automatically
- Use `http.Client` with timeout

## Health Checks

Expose at minimum:
- `/health-check/liveness` — process alive
- `/health-check/readiness` — external integrations healthy

## Context & Tracing

- `context.Context` as first parameter on all public functions doing I/O
- Never store context in struct fields
- Propagate trace headers via context

## Docker Multi-Stage Build

```dockerfile
FROM base    # Install tools
FROM ci      # Run tests, generate swagger
FROM builder # go build with CGO_ENABLED=0
FROM scratch # Final image — binary only
```

## CI/CD

Typical pipeline stages:
- `feature/*`, `hotfix/*` → run tests only
- `release/*` → deploy to staging (requires approval)
- `master/main` → promote to production (requires approval)
- Required jobs: `unit-test`, static analysis, security scan
- Multi-arch builds: `arm64 + amd64`

## Cobra CLI Commands

- Default: `entrypoint` — starts HTTP server
- `entrypoint routes` — lists all routes
- Add new commands: `cobra-cli add [name]`

## Naming Conventions

| Element | Convention |
|---|---|
| Packages | lowercase, single word |
| Files | snake_case |
| Functions | camelCase (exported: PascalCase) |
| Constants | PascalCase or UPPER_SNAKE_CASE |
| Interfaces | `-er` suffix (Handler, Reader, Storer) |

## Security

- Never commit credentials or tokens — use `<access_key>` placeholders
- Run security scanners in CI
- Use prepared statements for SQL
- Validate all inputs at adapter/controller layer
