---
name: golang-prometheus-metrics
description: Use when adding, modifying, or reviewing Prometheus metrics instrumentation in any Go service. Covers naming taxonomy, label design, metric types, cardinality rules, and implementation patterns.
---

# Golang Prometheus Metrics

## Overview

All service metrics should follow a strict taxonomy: `<namespace>_<subsystem>_<name>_<unit>`. Consistency enables cross-service dashboards and alerts.

## Naming Convention

```
<namespace>_<subsystem>_<name>_<unit>
```

| Part | Rule | Examples |
|---|---|---|
| Namespace | Short app/org prefix | `app_`, `svc_`, `myservice_` |
| Subsystem | Component being measured | `http`, `dependency`, `cache`, `business`, `worker`, `queue` |
| Name | Descriptive metric name | `requests`, `request_duration` |
| Unit | Always suffix with unit | `total`, `seconds`, `bytes`, `ratio` |

## Standard Metrics

### HTTP

```go
// Counter
app_http_requests_total
Labels: method, route, status_code, status_code_class, client_type, flow

// Histogram
app_http_request_duration_seconds
Labels: method, route, status_code, status_code_class, client_type, flow
Buckets: .005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10
```

### Dependency (external services)

```go
app_dependency_requests_total
app_dependency_duration_seconds
Labels: service, operation, status, route
```

### Cache

```go
app_cache_operations_total
Labels: cache_type, operation (hit|miss|set|delete), result (success|error), cache_tier (in_memory|redis|memcache|valkey)
```

### Business Events

```go
app_business_<event>_total
Labels: service, env, region
// Examples: app_business_checkout_completed_total, app_business_orders_processed_total
```

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

## Implementation

### Define in `internal/metrics/`

```go
package metrics

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    HttpRequestsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "app_http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "route", "status_code", "status_code_class", "client_type", "flow"},
    )

    HttpRequestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "app_http_request_duration_seconds",
            Help:    "HTTP request latency",
            Buckets: []float64{.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10},
        },
        []string{"method", "route", "status_code", "status_code_class", "client_type", "flow"},
    )
)
```

### Prometheus Middleware

```go
func PrometheusMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()
        duration := time.Since(start)
        statusCode := c.Writer.Status()

        labels := prometheus.Labels{
            "method":            c.Request.Method,
            "route":             c.FullPath(),
            "status_code":       strconv.Itoa(statusCode),
            "status_code_class": fmt.Sprintf("%dxx", statusCode/100),
            "client_type":       getClientType(c),
            "flow":              getFlow(c),
        }

        metrics.HttpRequestsTotal.With(labels).Inc()
        metrics.HttpRequestDuration.With(labels).Observe(duration.Seconds())
    }
}
```

### Business Metrics in Services

```go
var checkoutCompletedTotal = promauto.NewCounterVec(
    prometheus.CounterOpts{
        Name: "app_business_checkout_completed_total",
        Help: "Total completed checkouts",
    },
    []string{"payment_method"},
)

// In service method:
checkoutCompletedTotal.With(prometheus.Labels{
    "payment_method": req.PaymentMethod,
}).Inc()
```

### Exemplars (Trace Correlation)

```go
histogram.ObserveWithExemplar(
    duration.Seconds(),
    prometheus.Labels{"trace_id": traceID},
)
```

## Cache Hit Ratio — Derive, Don't Create Gauge

```promql
sum by (service, cache_type) (rate(app_cache_operations_total{operation="hit"}[5m]))
/
sum by (service, cache_type) (rate(app_cache_operations_total{operation=~"hit|miss"}[5m]))
```

## Common PromQL Queries

```promql
# Request rate
rate(app_http_requests_total[5m])

# Error rate
rate(app_http_requests_total{status_code_class=~"4xx|5xx"}[5m])

# P95 latency
histogram_quantile(0.95, rate(app_http_request_duration_seconds_bucket[5m]))

# Dependency error rate
rate(app_dependency_requests_total{status!="success"}[5m])
```

## DO / DON'T

**DO:**
- Use a consistent namespace prefix across all metrics
- Use consistent label names across all metrics
- Use histograms for latencies and sizes
- Include unit in metric name
- Use `promauto` for automatic registration
- Keep cardinality low

**DON'T:**
- Use high-cardinality labels: `user_id`, `request_id`, `cache_key`, `timestamp`
- Use Summary type — use Histogram instead
- Use Gauge where Counter is correct
- Mix metric types for the same measurement
- Create a hit-ratio gauge — calculate from counters
- Forget to document custom business metrics

## Expose Metrics Endpoint

Always expose `/metrics` endpoint using `prometheus/client_golang`:

```go
import "github.com/prometheus/client_golang/prometheus/promhttp"

router.GET("/metrics", gin.WrapH(promhttp.Handler()))
```
