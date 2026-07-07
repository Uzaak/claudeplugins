---
name: golang-use-context7
description: Use when adding a new Go library dependency or implementing features with any Go library. Always fetch docs before writing library-specific code.
---

# Golang — Use Context7 for Library Docs

## Overview

Always fetch up-to-date library documentation via Context7 before implementing any library-specific code. Context7 provides version-accurate, official docs — never rely on Stack Overflow or blog posts.

## When to Use

- Adding a new dependency to the project
- Implementing features with an unfamiliar library
- Troubleshooting library-specific issues
- Verifying correct API usage
- Checking for breaking changes or deprecations
- Understanding idiomatic usage patterns for a library

## Rules

- Resolve library ID first — don't guess the Context7 ID
- Check version-specific changes — APIs differ between major versions
- Prefer Context7 over any cached knowledge about the library

## Workflow

```text
1. resolve-library-id  →  get the Context7-compatible library ID
2. get-library-docs    →  fetch docs, specify topic if known
3. implement           →  follow docs + project standards
```

```text
Example:
"I need to add rate limiting middleware to gin"

1. resolve-library-id("gin-gonic/gin")
2. get-library-docs(id, topic="middleware")
3. Implement following your project's middleware stack order
```

## Common Go Libraries — Always Check

| Library | Purpose |
|---|---|
| `gin-gonic/gin` | HTTP router and web framework |
| `sirupsen/logrus` | Structured logging |
| `spf13/cobra` | CLI commands |
| `swaggo/swag` | Swagger documentation |
| `prometheus/client_golang` | Metrics collection |
| `stretchr/testify` | Testing assertions |
| `jarcoal/httpmock` | HTTP mocking for tests |
| `kelseyhightower/envconfig` | Environment configuration |
| `go.uber.org/zap` | High-performance structured logging |
| `golang.org/x/sync/errgroup` | Goroutine synchronization |

## Common Mistakes

| Mistake | Fix |
|---|---|
| Calling `get-library-docs` without resolving ID first | Always `resolve-library-id` first |
| Using Stack Overflow answer for library usage | Fetch from Context7 instead |
| Implementing without checking for deprecations | Include "deprecated" as a topic when verifying |
| Guessing gin middleware API from memory | Resolve gin → fetch docs with topic "middleware" |
