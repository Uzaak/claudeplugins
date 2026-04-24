---
name: analyse_endpoints
description: Use when the user runs /analyse_endpoints — inspects all application endpoints via Serena and cross-references them with DataDog metrics from the last 30 days to generate an Endpoints.md report at the project root.
argument-hint: [project-directory]
---

# uzaak: Analyse Endpoints

Produce a full endpoint-level analysis for the current project, combining static code inspection (via Serena) with live DataDog metrics from the last 30 days.

---

## Step 0 — Determine project directory

If an argument was provided, use it as the project directory. Otherwise use the current working directory.

Infer the application name from the project directory name (last path segment). This name will be used to find the service in DataDog.

Print: `[<project>] Starting analysis...`

---

## Step 1 — Check Serena availability (optional)

Serena is **optional**. Determine whether it is available by attempting to call `mcp__serena__check_onboarding_performed`.

- If the tool **does not exist or returns an error indicating the MCP server is not configured** → set `serena_available = false`. Print: `[<project>] Serena: not configured — will use file-based inspection`
- If the tool **exists and onboarding is already done** → set `serena_available = true`. Print: `[<project>] Serena: ready`
- If the tool **exists but onboarding has not been run** → run `mcp__serena__onboarding` now, then set `serena_available = true`. Print: `[<project>] Serena: onboarding completed`

---

## Step 2 — Locate the instrumented DataDog service(s)

A service appearing in the DataDog **Service Catalog** does not guarantee it has APM span data. Always resolve the correct instrumented service name(s) before querying metrics.

### 2a — Wildcard search

Query `mcp__datadog__search_datadog_services` using a wildcard: `name:<project>*` (not an exact match). Collect all returned service names.

If no results at all → print: `[<project>] WARNING: No DataDog services found — metrics will be unavailable.` Set `dd_service_list = []` and continue to Step 3.

### 2b — Select live/production variants

From the results, identify **production/live** services by looking for these patterns in the service name (in priority order):

1. `.live` suffix or substring
2. `prod` suffix or substring
3. If neither is present, take all returned variants as candidates

Discard QA, staging, and cluster-internal variants (`.qa`, `.staging`, `.svc.cluster.local`, etc.) unless they are the only results.

### 2c — Detect country split from service names

Inspect the live service names for country codes embedded in the name (e.g. `.br.`, `.co.`, `.ar.`, `.mx.`, `.cl.`).

- If **multiple countries** are encoded in the service names → set `multi_country = true`, record `countries` from the name segments, and set `dd_service_list` to the list of per-country live service names. Each service maps to its country (e.g. `<project>.br.live` → `BR`, `<project>.co.live` → `CO`).
- If **one or zero** country codes are found → set `multi_country = false` and set `dd_service_list` to the single (or only) live service name.

When country split is detected this way, **skip Step 4a** (tag-based country detection) entirely — the split is already resolved.

### 2d — Validate each candidate has actual APM data

For each service in `dd_service_list`, run a cheap validation query:

```
mcp__datadog__aggregate_spans  service:<name>  COUNT *  from: now-30d  to: now
```

- If the count is > 0 → the service is instrumented. Keep it.
- If the count is 0 or the query errors → the service has no span data. Remove it from `dd_service_list` and print: `[<project>] WARNING: <name> has no APM span data — skipping.`

If `dd_service_list` is empty after validation → set `dd_service = null` and continue with code-only analysis.

Otherwise print: `[<project>] DataDog service(s): <dd_service_list>`

---

## Step 3 — Discover all endpoints from the codebase

### 3a — Detect stack and controller conventions

| File present                          | Stack  | Controller pattern                                                                                 |
| ------------------------------------- | ------ | -------------------------------------------------------------------------------------------------- |
| `go.mod`                              | go     | files named `*_controller.go`, `*_handler.go`, or containing `gin.RouterGroup` / `http.HandleFunc` |
| `package.json`                        | node   | files in `controllers/`, `routes/`, or named `*.router.*`, `*.controller.*`                        |
| `composer.json`                       | php    | classes extending `Controller`, files in `app/Http/Controllers/`                                   |
| `requirements.txt` / `pyproject.toml` | python | files using `@app.route`, `@router.get/post/…`, Django `urlpatterns`                               |
| `Gemfile`                             | ruby   | files in `app/controllers/`                                                                        |

### 3b — Extract endpoint definitions

Use the appropriate inspection method based on `serena_available`:

**If `serena_available = true` — use Serena's symbolic tools:**

For each controller/router file found:

1. Use `mcp__serena__get_symbols_overview` to list symbols.
2. For each symbol that looks like a handler or route definition, use `mcp__serena__find_symbol` to read its body.
3. Extract: HTTP method, path pattern, handler name, and a one-line description of what the handler does (inferred from its name, comments, or body).

**If `serena_available = false` — use file-based inspection:**

For each controller/router file found (matched by the patterns in 3a), read the file directly and extract route definitions by scanning for:

- HTTP method keywords (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HandleFunc`, `router.`, `app.`, `@app.route`, etc.)
- Path strings (quoted strings starting with `/`)
- Handler function names adjacent to route registrations

Build a list of endpoints regardless of method used:

```
endpoints = [
  { method, path, handler, description },
  ...
]
```

Print: `[<project>] Found <N> endpoints in codebase`

### 3c — Discover outbound calls from codebase

Scan the codebase for each of the following outbound dependency types. Use Serena's symbolic tools when `serena_available = true`, or direct file scanning otherwise.

**HTTP clients** — look for:

- Go: `http.Get`, `http.Post`, `http.NewRequest`, `resty`, `retryablehttp`
- Node: `axios`, `fetch`, `got`, `node-fetch`, `request`
- PHP: `Guzzle`, `Http::`, `curl_exec`
- Python: `requests.get/post/…`, `httpx`, `urllib`
- Ruby: `Net::HTTP`, `Faraday`, `HTTParty`

For each call site, extract the target host/URL (or the variable/config key that holds it) and the surrounding context to infer its purpose.

**gRPC clients** — look for:

- Go: `grpc.Dial`, `grpc.NewClient`, proto-generated `NewXxxClient()`
- Node: `@grpc/grpc-js`, `grpc.loadPackageDefinition`
- PHP: generated proto stubs extending `\Grpc\BaseStub`
- Python: `grpc.insecure_channel`, `grpc.secure_channel`, proto-generated stubs
- Ruby: generated proto stubs

For each, extract the target service name/address and the RPC methods called.

**Databases** — look for connection setup or ORM usage:

- Go: `sql.Open`, `gorm.Open`, `sqlx.Connect`
- Node: `knex`, `sequelize`, `mongoose`, `pg`, `mysql2`, `typeorm`
- PHP: `PDO`, `Eloquent`, `DB::`, `doctrine`
- Python: `SQLAlchemy`, `django.db`, `psycopg2`, `pymongo`
- Ruby: `ActiveRecord`, `Sequel`, `pg`

Extract: database system (postgres, mysql, mongo, etc.), host/DSN variable name, and purpose inferred from model/schema names or surrounding code.

**Caches** — look for:

- Go: `redis.NewClient`, `go-redis`, `redigo`, `gomemcache`
- Node: `ioredis`, `redis`, `memcached`, `node-cache`
- PHP: `Redis`, `Predis`, `Memcached`
- Python: `redis.Redis`, `aioredis`, `pymemcache`, `django.core.cache`
- Ruby: `Redis.new`, `Dalli`

Extract: cache system (redis, memcached, etc.), host/config key, and purpose.

Build an outbound dependency list:

```
outbound = [
  { type, target, description },  // type: http | grpc | database | cache
  ...
]
```

Print: `[<project>] Found <N> outbound dependencies in codebase`

---

## Step 4 — Fetch DataDog metrics for each endpoint (last 30 days)

Skip this step if `dd_service == null`.

### 4a — Detect countries (only if not already resolved in Step 2c)

If `multi_country` was already set in Step 2c, skip this step.

Otherwise, attempt tag-based detection: query `mcp__datadog__aggregate_spans` for all distinct values of the `country` tag under each service in `dd_service_list` in the last 30 days.

- If **2+ distinct country tag values** are found → set `multi_country = true`, record `countries`.
- If **1 or zero** distinct values → set `multi_country = false`, record the single country or `"default"`.

Print: `[<project>] Countries detected: <list or "single deployment">`

### 4b — Request and error counts (4xx/5xx) per inbound endpoint

When `multi_country = false` (single service in `dd_service_list`), query once per endpoint:

```
mcp__datadog__aggregate_spans
  service:<dd_service>  resource_name:<METHOD> <path>
  COUNT *                                          → request_count
  COUNT * where @http.status_code:[400 TO 499]     → user_error_count   (4xx — client/user errors)
  COUNT * where @http.status_code:[500 TO 599]     → server_error_count (5xx — server errors)
  from: now-30d  to: now
```

When `multi_country = true` (multiple services in `dd_service_list`, one per country), query once per service (country). Each service name maps to its country from Step 2c or 4a.

Do **not** add `span.kind:server` as a filter — some services do not tag this field and the filter will return empty results. If a query returns zero results, retry without any `span.kind` filter before concluding there is no data.

Record `request_count`, `user_error_count` (4xx), and `server_error_count` (5xx) (total and per-country if applicable). Default to `N/A` only after at least one retry attempt.

### 4c — Inbound endpoints only in DataDog (not found in codebase)

For each service in `dd_service_list`, query distinct `resource_name` values in the last 30 days:

```
mcp__datadog__aggregate_spans  service:<name>  COUNT *  group by resource_name
  from: now-30d  to: now
```

Do **not** add a `span.kind` filter here either.

Merge results across all services. Any `resource_name` not matched to a codebase endpoint is added to the list with `handler = "(unknown — only seen in DataDog)"`.

Print: `[<project>] DataDog metrics fetched for <N> inbound endpoints`

### 4d — Outbound metrics from DataDog

Run all queries once per service in `dd_service_list`. When `multi_country = true`, attribute each service's results to its country.

**HTTP outbound** — group by `http.url` host or `peer.service`:

```
mcp__datadog__aggregate_spans  service:<name>  span.kind:client  http.url:*
  COUNT *                                          → request_count
  COUNT * where @http.status_code:[400 TO 499]     → user_error_count   (4xx — client/user errors)
  COUNT * where @http.status_code:[500 TO 599]     → server_error_count (5xx — server errors)
  group by peer.service (or http.url host)
  from: now-30d  to: now
```

Exclude entries where the destination matches the service's own hostname.

**gRPC outbound** — group by `rpc.service` + `rpc.method`:

```
mcp__datadog__aggregate_spans  service:<name>  span.kind:client  rpc.system:grpc
  COUNT *  /  COUNT * where error:1   (gRPC uses span-level errors, not HTTP status codes)
  group by rpc.service, rpc.method
```

**Database outbound** — group by `db.system` + `db.name`:

```
mcp__datadog__aggregate_spans  service:<name>  span.kind:client  db.system:*
  (exclude redis/memcached/elasticache — handled below)
  COUNT *  /  COUNT * where error:1   (DB spans use span-level errors, not HTTP status codes)
  group by db.system, db.name
```

**Cache outbound** — group by `db.system` + `peer.hostname`:

```
mcp__datadog__aggregate_spans  service:<name>  span.kind:client
  db.system:(redis OR memcached OR elasticache)
  COUNT *  /  COUNT * where error:1   (cache spans use span-level errors, not HTTP status codes)
  group by db.system, peer.hostname
```

If `span.kind:client` returns no results for a query, retry without the `span.kind` filter before treating the result as empty.

Cross-reference each DataDog outbound entry against `outbound[]` from Step 3c to enrich with the codebase-derived description. If no match, set description to `"(unknown — only seen in DataDog)"`.

Default all counts to `N/A` only after at least one retry.

Print: `[<project>] DataDog outbound metrics fetched: <N> HTTP, <N> gRPC, <N> DB, <N> cache`

---

## Step 4e — Outbound-per-Inbound correlation

Skip this step if `dd_service == null`.

**Goal**: For each outbound destination, determine which inbound endpoints are calling it, and with what frequency and error rate. This lets you see, for example, that a database is queried 500 times but 450 calls come from `GET /users` and 50 from `GET /cart`, or that `some.cool.api.com` has a 10% error rate when called from `GET /products` but 0% from `GET /payments`.

### Correlation strategy — try in order, stop when one works

**Strategy A — `@http.route` multi-dimensional grouping (preferred)**

Most web-framework DataDog tracers propagate the matched HTTP route to all child spans in the request context (e.g. via `@http.route`). Query each outbound type grouped by the outbound destination AND `@http.route`:

```
# HTTP outbound (4xx and 5xx separated)
mcp__datadog__aggregate_spans  service:<name>  span.kind:client  http.url:*
  COUNT *  /  COUNT * where @http.status_code:[400 TO 499]  /  COUNT * where @http.status_code:[500 TO 599]
  group by peer.service, @http.route
  from: now-30d to: now

# gRPC outbound (span-level errors, no HTTP status codes)
mcp__datadog__aggregate_spans  service:<name>  span.kind:client  rpc.system:grpc
  COUNT *  /  COUNT * where error:1
  group by rpc.service, rpc.method, @http.route

# Database outbound (span-level errors, no HTTP status codes)
mcp__datadog__aggregate_spans  service:<name>  span.kind:client  db.system:*
  COUNT *  /  COUNT * where error:1
  group by db.system, db.name, @http.route

# Cache outbound (span-level errors, no HTTP status codes)
mcp__datadog__aggregate_spans  service:<name>  span.kind:client  db.system:(redis OR memcached OR elasticache)
  COUNT *  /  COUNT * where error:1
  group by db.system, peer.hostname, @http.route
```

If `@http.route` returns multiple distinct non-null values that match known inbound endpoint paths → strategy A succeeded. Set `correlation_method = "tag:http.route"`. Build `outbound_per_inbound` from the result.

If `span.kind:client` returns no results for any query, retry without `span.kind` before moving to Strategy B.

---

**Strategy B — `@resource_name` parent context grouping**

Some DataDog agents propagate the parent server span's `resource_name` to child spans. Replace `@http.route` with `@resource_name` in all Strategy A queries and repeat. If the returned `@resource_name` values match known inbound endpoint patterns (e.g. `GET /users`, `POST /orders`) → set `correlation_method = "tag:resource_name"`.

---

**Strategy C — per-inbound sampling (fallback)**

If neither A nor B yields useful data, fall back to a sampling approach for the top-10 inbound endpoints by request count.

For each top-10 inbound endpoint `METHOD /path`:

1. Use `mcp__datadog__search_datadog_spans` to retrieve a sample of server spans for this endpoint (up to 50 traces):
   ```
   search_datadog_spans  service:<name>  resource_name:"METHOD /path"  span.kind:server
   limit:50  from:now-30d to:now
   ```
2. Collect the returned `trace_id` values.
3. For each outbound type, query client spans within those trace IDs and aggregate by destination. Because `aggregate_spans` may not support multi-value trace_id filtering directly, instead use `search_datadog_spans` to retrieve client spans from those traces and tally them manually:
   ```
   search_datadog_spans  service:<name>  span.kind:client  trace_id:<id1> OR trace_id:<id2> ...
   ```
   For HTTP outbound spans, extract `http.status_code` from each span to separate `user_errors` (4xx) from `server_errors` (5xx) when tallying. For gRPC, DB, and cache spans, tally `error:1` as a single error count.
4. Scale sampled counts to 30d totals: `scaled_count = sampled_count × (total_30d_requests / sample_size)`. Mark all counts in the report with `~` (e.g. `~4,500`) to indicate they are estimates.

Set `correlation_method = "sampling (top-10 inbound, ~50 traces each)"`.

---

**Strategy D — graceful degradation**

If no strategy yields meaningful correlation data, set `correlation_available = false`. The "Outbound per Inbound" section will contain only a note explaining that correlation was not available and what instrumentation changes would enable it.

---

### Build the correlation map

After running the chosen strategy, build:

```
outbound_per_inbound = {
  "GET /users": {
    description: "...",   // from Step 3 endpoint list
    http:      [{ target, requests, user_errors, server_errors }, ...],   // user_errors=4xx, server_errors=5xx
    grpc:      [{ service, method, requests, errors }, ...],               // span-level errors (no HTTP status codes)
    databases: [{ system, database, queries, errors }, ...],               // span-level errors (no HTTP status codes)
    caches:    [{ system, host, operations, errors }, ...],                // span-level errors (no HTTP status codes)
  },
  ...
}
```

Inbound endpoints with zero total outbound calls (no client-span correlation found) are omitted from the map.

When `multi_country = true`, record per-country breakdown only if the correlation strategy returns country-level data (i.e. the group-by already includes per-country service names). Otherwise aggregate across countries and note this in the report.

Print: `[<project>] Outbound-per-inbound: <correlation_method> / <N> inbound endpoints with outbound data`

---

## Step 5 — Rotate existing endpoint files

Before writing the new report, apply this rotation logic in order:

1. If `<project-dir>/Endpoints_old.md` exists → **delete** it.
2. If `<project-dir>/Endpoints.md` exists → **rename/move** it to `Endpoints_old.md`.
3. Proceed to write the new `Endpoints.md`.

---

## Step 6 — Write Endpoints.md

Create `<project-dir>/Endpoints.md` with two top-level sections: **Inbound** and **Outbound**. Use the single-country or multi-country variant for each section independently (it is possible the inbound data is multi-country while outbound is not, or vice versa — detect and apply per section).

### Document header (always)

```markdown
# Endpoint Analysis — <project-name>

> Last analysis: <YYYY-MM-DD HH:MM:SS UTC>
> DataDog service: <dd_service or "not found">
> Period: last 30 days
```

---

### Inbound section — single-country

```markdown
## Inbound

Requests received by this application.

| Method | Path    | Description                | Requests (30d) | User Errors (4xx) | Server Errors (5xx) | 4xx Rate | 5xx Rate |
| ------ | ------- | -------------------------- | -------------- | ----------------- | ------------------- | -------- | -------- |
| GET    | /health | Liveness probe             | 120,000        | 0                 | 0                   | 0.00%    | 0.00%    |
| POST   | /users  | Creates a new user account | 4,300          | 10                | 2                   | 0.23%    | 0.05%    |
```

### Inbound section — multi-country

```markdown
## Inbound

Requests received by this application.
Countries: <country1>, <country2>, ...

### GET /health

Liveness probe.

| Country   | Requests (30d) | User Errors (4xx) | Server Errors (5xx) | 4xx Rate  | 5xx Rate  |
| --------- | -------------- | ----------------- | ------------------- | --------- | --------- |
| BR        | 100,000        | 0                 | 0                   | 0.00%     | 0.00%     |
| AR        | 20,000         | 0                 | 0                   | 0.00%     | 0.00%     |
| **Total** | **120,000**    | **0**             | **0**               | **0.00%** | **0.00%** |

### POST /users

Creates a new user account.

| Country   | Requests (30d) | User Errors (4xx) | Server Errors (5xx) | 4xx Rate  | 5xx Rate  |
| --------- | -------------- | ----------------- | ------------------- | --------- | --------- |
| BR        | 3,500          | 7                 | 1                   | 0.20%     | 0.03%     |
| AR        | 800            | 3                 | 1                   | 0.38%     | 0.13%     |
| **Total** | **4,300**      | **10**            | **2**               | **0.23%** | **0.05%** |
```

---

### Outbound section — single-country

```markdown
## Outbound

External calls made by this application.

### HTTP

| Destination    | Description                            | Requests (30d) | User Errors (4xx) | Server Errors (5xx) | 4xx Rate | 5xx Rate |
| -------------- | -------------------------------------- | -------------- | ----------------- | ------------------- | -------- | -------- |
| api.stripe.com | Payment processing                     | 4,200          | 9                 | 2                   | 0.21%    | 0.05%    |
| auth.internal  | Internal auth service token validation | 80,000         | 2                 | 0                   | 0.00%    | 0.00%    |

### gRPC

| Service               | Method  | Description             | Requests (30d) | Errors (30d) | Error Rate |
| --------------------- | ------- | ----------------------- | -------------- | ------------ | ---------- |
| inventory.ItemService | GetItem | Fetches item stock data | 12,000         | 5            | 0.04%      |

> gRPC errors use span-level `error:1` (not HTTP status codes). A single **Error Rate** column is shown.

### Databases

| System   | Database  | Description               | Queries (30d) | Errors (30d) | Error Rate |
| -------- | --------- | ------------------------- | ------------- | ------------ | ---------- |
| postgres | orders_db | Primary orders data store | 950,000       | 3            | 0.00%      |
| mongo    | catalog   | Product catalogue reads   | 200,000       | 0            | 0.00%      |

> Database errors use span-level `error:1` (not HTTP status codes). A single **Error Rate** column is shown.

### Caches

| System | Host                | Description                  | Operations (30d) | Errors (30d) | Error Rate |
| ------ | ------------------- | ---------------------------- | ---------------- | ------------ | ---------- |
| redis  | cache.internal:6379 | Session and rate-limit cache | 1,200,000        | 1            | 0.00%      |

> Cache errors use span-level `error:1` (not HTTP status codes). A single **Error Rate** column is shown.
```

### Outbound section — multi-country

When `multi_country = true`, each outbound entry also gets a per-country breakdown. Use the same subsection format as the multi-country Inbound section (subsection heading = destination + method/system, table with Country / Requests / Errors / Error Rate rows, bold Total last).

```markdown
## Outbound

External calls made by this application.
Countries: <country1>, <country2>, ...

### HTTP

#### api.stripe.com

Payment processing.

| Country   | Requests (30d) | User Errors (4xx) | Server Errors (5xx) | 4xx Rate  | 5xx Rate  |
| --------- | -------------- | ----------------- | ------------------- | --------- | --------- |
| BR        | 3,500          | 7                 | 2                   | 0.20%     | 0.06%     |
| AR        | 700            | 2                 | 0                   | 0.29%     | 0.00%     |
| **Total** | **4,200**      | **9**             | **2**               | **0.21%** | **0.05%** |

### gRPC

... (same pattern)

### Databases

... (same pattern)

### Caches

... (same pattern)
```

---

### Outbound per Inbound section

Only include this section when `correlation_available = true` (at least one inbound endpoint has correlated outbound data). When `correlation_available = false`, insert instead:

```markdown
## Outbound per Inbound

> Correlation data unavailable. No inbound context tag (`@http.route` or `@resource_name`) was
> found on outbound spans, and sampling returned no usable traces. To enable this section, ensure
> your web framework's DataDog auto-instrumentation propagates the matched route to child spans.
```

When data is available:

```markdown
## Outbound per Inbound

Outbound calls broken down by the inbound endpoint that triggered them.

> Correlation method: <correlation_method>
> Inbound endpoints with outbound data: <N>
> Counts marked `~` are estimates extrapolated from a sample of traces.

### GET /users

<description of endpoint from Step 3>

#### HTTP

| Destination       | Requests (30d) | User Errors (4xx) | Server Errors (5xx) | 4xx Rate | 5xx Rate |
| ----------------- | -------------- | ----------------- | ------------------- | -------- | -------- |
| auth.internal     | 420,000        | 0                 | 0                   | 0.00%    | 0.00%    |
| some.cool.api.com | 5,000          | 200               | 50                  | 4.00%    | 1.00%    |

#### gRPC

| Service               | Method  | Requests (30d) | Errors (30d) | Error Rate |
| --------------------- | ------- | -------------- | ------------ | ---------- |
| inventory.ItemService | GetItem | 8,000          | 2            | 0.03%      |

#### Databases

| System   | Database  | Queries (30d) | Errors (30d) | Error Rate |
| -------- | --------- | ------------- | ------------ | ---------- |
| postgres | orders_db | 450,000       | 1            | 0.00%      |

#### Caches

| System | Host                | Operations (30d) | Errors (30d) | Error Rate |
| ------ | ------------------- | ---------------- | ------------ | ---------- |
| redis  | cache.internal:6379 | 900,000          | 0            | 0.00%      |

### POST /orders

<description>

#### HTTP

| Destination         | Requests (30d) | User Errors (4xx) | Server Errors (5xx) | 4xx Rate | 5xx Rate |
| ------------------- | -------------- | ----------------- | ------------------- | -------- | -------- |
| payment.gateway.com | 12,000         | 120               | 30                  | 1.00%    | 0.25%    |
```

**Multi-country in this section**: When `multi_country = true` and the correlation step returned per-country data, add per-country sub-tables within each inbound endpoint subsection (same Country / Requests / Errors / Error Rate format with bold Total row). If per-country breakdown is not available at the correlation level, aggregate across countries and add: `> Note: country breakdown not available for this correlation; totals shown.`

**Formatting rules for this section:**

- Omit sub-subsections (HTTP / gRPC / Databases / Caches) that have no entries for a given inbound endpoint.
- Sort inbound endpoints by total outbound request count descending (sum across all outbound types).
- Within each inbound endpoint, sort rows by request count descending.
- Omit inbound endpoints that have zero correlated outbound calls.
- Format numbers with comma separators; Error Rate = `errors / requests * 100`, 2 decimal places.

---

### Outbound Notes block (always append)

```markdown
---

## Notes

- Inbound entries marked `(unknown — only seen in DataDog)` appear in traffic data but have no matching controller in the codebase.
- Outbound entries marked `(unknown — only seen in DataDog)` appear as client spans in DataDog but were not found as explicit call sites in the codebase.
- Metrics are aggregated over the last 30 days from DataDog service(s): `<dd_service_list>`.
- Country data is derived from per-country service names in DataDog (e.g. `*.br.*`, `*.co.*`) or from the `country` span tag when service names are not country-scoped.
- If DataDog service was not found or had no APM span data, all metric columns show `N/A`.
- **Error classification for HTTP spans:** `User Errors (4xx)` counts HTTP 4xx responses (client/user errors — e.g. 400 Bad Request, 401 Unauthorized, 404 Not Found, 409 Conflict). `Server Errors (5xx)` counts HTTP 5xx responses (server errors — e.g. 500 Internal Server Error, 502 Bad Gateway, 503 Service Unavailable). gRPC, database, and cache spans use span-level `error:1` and are reported with a single **Error Rate** column since HTTP status codes do not apply to them.
- **On outbound 4xx rates for auth/identity services:** high 4xx rates on outbound calls are often expected — for example, `POST /token` returning 401 for wrong passwords, or `POST /users` returning 409 for duplicate accounts. Treat outbound 4xx rates on auth-adjacent endpoints with context before classifying them as bugs. High 5xx rates, however, are abnormal and should be investigated regardless of the endpoint.
```

---

### Formatting rules (all sections)

- Sort inbound endpoints and outbound entries by total request count descending; rows without metrics last.
- In multi-country tables, sort country rows by request count descending; **Total** row always last in bold.
- Format large numbers with comma separators (e.g. `1,234,567`).
- For HTTP spans (inbound endpoints and outbound HTTP): compute **4xx Rate** as `user_errors / requests * 100` and **5xx Rate** as `server_errors / requests * 100`, both 2 decimal places; show `N/A` if either value is missing.
- For non-HTTP spans (gRPC, databases, caches): compute **Error Rate** as `errors / requests * 100`, 2 decimal places; show `N/A` if either value is missing.
- Omit an entire outbound subsection (HTTP / gRPC / Databases / Caches) if no entries were found for it in either the codebase or DataDog.

---

## Step 7 — Ensure Endpoints.md is referenced in CLAUDE.md

Check whether `<project-dir>/CLAUDE.md` exists.

- **Does not exist** → create it with this content:

  ```markdown
  # Project: <project-name>

  ## Endpoint Reference

  See [Endpoints.md](./Endpoints.md) for a full list of application endpoints, their purpose, and request/error metrics from the last 30 days.
  Always consult this file before reasoning about which endpoints exist or how they behave.
  ```

- **Exists, does NOT mention `Endpoints.md`** → append the following block at the end:

  ```markdown
  ## Endpoint Reference

  See [Endpoints.md](./Endpoints.md) for a full list of application endpoints, their purpose, and request/error metrics from the last 30 days.
  Always consult this file before reasoning about which endpoints exist or how they behave.
  ```

- **Exists and already mentions `Endpoints.md`** → leave it unchanged.

Print: `[<project>] CLAUDE.md updated`

---

## Step 8 — Summary

Always print this summary at the end:

```
╔══════════════════════════════════════════════════╗
║            Endpoint Analysis Complete            ║
║  <project-name>                                  ║
╠══════════════════════════════════════════════════╣
║ INBOUND                                          ║
║   Endpoints in code     : <N>                    ║
║   Endpoints in DD       : <N>  (<dd_service>)    ║
║   Total unique          : <N>                    ║
╠══════════════════════════════════════════════════╣
║ OUTBOUND                                         ║
║   HTTP destinations     : <N>                    ║
║   gRPC services         : <N>                    ║
║   Databases             : <N>                    ║
║   Caches                : <N>                    ║
╠══════════════════════════════════════════════════╣
║ OUTBOUND PER INBOUND                             ║
║   Correlation method    : <method or N/A>        ║
║   Inbound with data     : <N> / <total inbound>  ║
╠══════════════════════════════════════════════════╣
║ Analysis written to     : Endpoints.md            ║
║ Previous analysis saved : Endpoints_old.md / none ║
║ CLAUDE.md updated       : yes / already current  ║
╠══════════════════════════════════════════════════╣
║ Analysis timestamp      : <YYYY-MM-DD HH:MM UTC> ║
╚══════════════════════════════════════════════════╝
```

---

## Key rules

- **Never modify source code or tests.** This skill is read-only with respect to application code.
- **Always rotate.** Never overwrite Endpoints.md directly — always follow the rotation sequence in Step 5.
- **Always write the timestamp.** The analysis file must record exactly when it was generated.
- **Always update CLAUDE.md.** Even if Endpoints.md is empty or metrics are unavailable.
- **DataDog unavailability is not a blocker.** If the service is not found in DataDog, complete the analysis using only codebase data and fill all metric columns with `N/A`.
- **Serena is optional.** If its MCP server is not configured, fall back to direct file inspection — never fail or stop because Serena is absent.
- **Country detection is automatic.** Prefer service-name-encoded country codes (`.br.`, `.co.`, etc.) over span tags — span tags are unreliable and may be absent. Never ask the user.
- **Service Catalog ≠ APM data.** A name returned by `search_datadog_services` only proves a catalog entry exists. Always validate with a `COUNT *` span query before trusting any service name.
- **Always use wildcard service lookup.** Search `name:<project>*`, then filter for live/prod variants. Never query with the bare project name as an exact service ID.
- **Never gate on `span.kind`.** Some services do not emit this tag. Always retry without it before reporting empty results.
- **High outbound 4xx rates on auth services can be normal.** 401s (wrong password), 409s (duplicate user), and similar 4xx responses inflate user error rates on auth-adjacent endpoints. Note this in the report rather than treating it as a bug. High 5xx rates are always abnormal and should be investigated.
- **Outbound-per-inbound correlation is best-effort.** If no inbound context tag is found on outbound spans (Strategy A/B) and sampling yields no traces (Strategy C), the section must still appear in the report — either with data or with a clear note explaining unavailability. Never silently omit the section.
- **Correlation counts from sampling are approximate.** Always mark sampled/extrapolated values with `~` and note the sample size in the report. Do not present them as exact aggregations.
