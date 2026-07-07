---
name: golang-prometheus-metrics
description: Use when adding, modifying, or reviewing Prometheus metrics instrumentation in any Go service. Covers naming taxonomy, label design, metric types, cardinality rules, and implementation patterns.
---

# Golang Prometheus Metrics

## Overview

All service metrics follow a strict taxonomy: `<namespace>_<subsystem>_<name>_<unit>`. Consistency enables cross-service dashboards and alerts.

Implementation code and PromQL recipes: [references/implementation.md](references/implementation.md).

## Hard Rules

- Always expose a `/metrics` endpoint using `prometheus/client_golang` (`promhttp.Handler()`).
- Use `promauto` for automatic registration; define shared metrics in `internal/metrics/`.
- Never use high-cardinality labels: `user_id`, `request_id`, `cache_key`, `timestamp`.
- Never use the Summary type — use Histogram.
- Never create a hit-ratio gauge — derive it from hit/miss counters in PromQL.
- Always include the unit in the metric name (`_total`, `_seconds`, `_bytes`, `_ratio`).

## Naming Convention

```text
<namespace>_<subsystem>_<name>_<unit>
```

| Part | Rule | Examples |
|---|---|---|
| Namespace | Short app/org prefix | `app_`, `svc_`, `myservice_` |
| Subsystem | Component being measured | `http`, `dependency`, `cache`, `business`, `worker`, `queue` |
| Name | Descriptive metric name | `requests`, `request_duration` |
| Unit | Always suffix with unit | `total`, `seconds`, `bytes`, `ratio` |

## Standard Metrics

| Metric | Type | Labels |
|---|---|---|
| `app_http_requests_total` | Counter | method, route, status_code, status_code_class, client_type, flow |
| `app_http_request_duration_seconds` | Histogram (buckets: .005–10) | same as above |
| `app_dependency_requests_total` / `app_dependency_duration_seconds` | Counter / Histogram | service, operation, status, route |
| `app_cache_operations_total` | Counter | cache_type, operation (hit\|miss\|set\|delete), result (success\|error), cache_tier (in_memory\|redis\|memcache\|valkey) |
| `app_business_<event>_total` (e.g. `app_business_checkout_completed_total`, `app_business_orders_processed_total`) | Counter | service, env, region |

HTTP histogram buckets: `.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10`.

## Label Dictionary

| Label | Description | Values |
|---|---|---|
| `route` | Parameterized path | `/users/:id`, `/cart` |
| `status_code` | HTTP response code | 200, 404, 503 |
| `status_code_class` | Response class | 2xx, 4xx, 5xx |
| `client_type` | Client category | web, ios, android, n/a |
| `flow` | Business process | login, registration, checkout |
| `service` | External dependency name | payment-api, auth-service |
| `operation` | Dependency action | GetUser, CreatePayment |
| `cache_tier` | Cache layer | in_memory, redis, memcache, valkey |

## Metric Types

| Type | Use For | Query |
|---|---|---|
| Counter | Cumulative events that only increase | `rate(metric[5m])` |
| Gauge | Current value (can go up/down) | `metric` |
| Histogram | Latencies and sizes (use buckets) | `histogram_quantile(0.99, rate(metric_bucket[5m]))` |
| Summary | **Avoid** — use histograms instead | — |

## DO / DON'T

**DO:** consistent namespace prefix; consistent label names; histograms for latencies and sizes; unit in metric name; `promauto`; low cardinality.

**DON'T:** high-cardinality labels; Summary type; Gauge where Counter is correct; mixed metric types for the same measurement; hit-ratio gauges; undocumented custom business metrics.
