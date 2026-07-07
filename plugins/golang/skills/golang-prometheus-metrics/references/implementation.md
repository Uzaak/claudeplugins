# Golang Prometheus Metrics — Implementation & Queries

Go snippets are non-executable reference examples; PromQL snippets are query recipes.

## Define Metrics in `internal/metrics/`

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

## Prometheus Middleware (gin)

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

## Business Metrics in Services

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

## Exemplars (Trace Correlation)

```go
histogram.ObserveWithExemplar(
    duration.Seconds(),
    prometheus.Labels{"trace_id": traceID},
)
```

## Expose Metrics Endpoint

```go
import "github.com/prometheus/client_golang/prometheus/promhttp"

router.GET("/metrics", gin.WrapH(promhttp.Handler()))
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
