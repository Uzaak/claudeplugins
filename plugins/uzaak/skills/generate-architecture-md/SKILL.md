---
name: generate-architecture-md
description: Use when the user runs /generate-architecture-md — reads the project's data models, repositories, service layer, and runtime configuration to produce an Architecture.md focused on what the system stores, where it stores it, what it caches, and what external services it depends on. Not about code structure.
argument-hint: [project-directory]
---

# uzaak: Generate Architecture.md

Produce a runtime-focused `Architecture.md` that answers: **what does this system do with data?** Document what is persisted where, what is cached, what external services are called, and how data flows through key operations. Do NOT document directory structure or coding patterns.

Print: `[<project>] Starting architecture analysis...`

---

## Step 0 — Determine project directory

If an argument was provided, use it as the project directory. Otherwise use the current working directory.

Infer the application name from the project directory name (last path segment).

---

## Step 1 — Detect stack and runtime dependencies

### 1a — Stack detection

Detect the primary tech stack (first match wins):

| File present | Stack |
|---|---|
| `go.mod` | go |
| `package.json` | node |
| `composer.json` | php |
| `requirements.txt` or `pyproject.toml` | python |
| `Gemfile` | ruby |
| (none) | unknown |

### 1b — Identify data infrastructure from dependencies

Parse the primary dependency file for the detected stack and identify what data infrastructure the project uses:

| What to look for | Examples |
|---|---|
| **Relational databases** | `gorm`, `sqlx`, `sequelize`, `typeorm`, `django`, `eloquent`, `sqlalchemy` |
| **Document / NoSQL databases** | `mongo-driver`, `mongoose`, `dynamo`, `firestore` |
| **Caches** | `go-redis`, `gomemcache`, `ioredis`, `node-memcached`, `django-redis`, `predis` |
| **Message queues / event streams** | `aws-sdk` (SQS/SNS), `amqplib`, `kafka-go`, `sarama`, `bull`, `celery`, `pika` |
| **Search engines** | `elastic`, `opensearch`, `typesense`, `meilisearch` |
| **Object storage** | `aws-sdk` (S3), `minio`, `gcs` |
| **Auth libraries** | `jwt-go`, `golang-jwt`, `jsonwebtoken`, `passport`, `devise`, `dj-rest-auth` |
| **HTTP client libraries** | `resty`, `axios`, `guzzle`, `httpx`, `faraday` |
| **gRPC** | `grpc`, `google.golang.org/grpc`, `@grpc/grpc-js` |

Record `infra_deps[]` = `{ type, library, notes }`.

Print: `[<project>] Detected infrastructure: <infra_deps types joined by ", ">`

### 1c — Configuration discovery

Find environment variable declarations and config structs to identify hostnames, DSNs, and service URLs:

- `.env`, `.env.example`, `.env.sample`, `.env.test`
- Config structs/classes that reference `os.Getenv`, `process.env`, `os.environ`, `getenv`
- `config.go`, `config.py`, `config.js`, `settings.py`, `application.yml`, `application.properties`

Extract:
- Database DSN / host / port / database name
- Cache host / port / TTL settings
- Queue names / topic names / ARNs
- External service base URLs and API key variable names

Record as `config_map[]` = `{ key, type, value_or_example, purpose }`.

---

## Step 2 — Data model analysis

Locate and read data model definitions for the detected stack:

| Stack | Where to look | What to read |
|---|---|---|
| **go** | Files with `struct` + `gorm:` tags or `db:` tags; migration files under `db/migrations/`, `migrations/`, `schema/` | Struct field names, column names, types, constraints; migration `CREATE TABLE` statements |
| **node** | Sequelize model files (`define(`, `Model.init(`); Mongoose schema files (`new Schema(`); TypeORM entity files (`@Entity`, `@Column`) | Field names, types, `allowNull`, relationships |
| **php** | Eloquent model files (`$fillable`, `$casts`, `$table`); migration files under `database/migrations/` | Fillable fields, casts, relationships (`hasMany`, `belongsTo`) |
| **python** | Django model files (`models.Model`); SQLAlchemy declarative models (`Base`); Alembic migration files | Field definitions, `db.Column`, relationships, `ForeignKey` |
| **ruby** | ActiveRecord migration files under `db/migrate/`; model files with `belongs_to`, `has_many` | Column types, validations, associations |

For each model / entity, record:
- **Entity name** (table or collection)
- **Storage system** (which DB, inferred from config)
- **Fields**: name, type, notable constraints (nullable, unique, indexed, encrypted)
- **Relationships**: belongs-to, has-many (other entity names only — no code paths)
- **Special behaviors**: soft deletes (`deleted_at`, `paranoid`), timestamps (`created_at`, `updated_at`), tenant scoping

Record as `models[]` = `{ entity, storage, fields[], relationships[], special_behaviors[] }`.

Print: `[<project>] Found <N> data models`

---

## Step 3 — Cache usage analysis

Search the codebase for cache read/write patterns.

**Go** — look for calls to `.Get(`, `.Set(`, `.SetEX(`, `.HSet(`, `memcache.Item{`, `cache.Get(`  
**Node** — look for `client.get(`, `client.set(`, `client.setEx(`, `cache.wrap(`  
**PHP** — look for `Cache::get(`, `Cache::put(`, `Cache::remember(`, `$redis->get(`  
**Python** — look for `cache.get(`, `cache.set(`, `cache.get_or_set(`, `r.get(`, `r.setex(`  
**Ruby** — look for `Rails.cache.read`, `Rails.cache.write`, `Rails.cache.fetch`

For each cache usage, extract:
- **Cache system** (Redis, Memcached — inferred from dependency)
- **Key pattern** (e.g. `user:<id>`, `product:<slug>:details`)
- **TTL** if set explicitly
- **What is cached** (inferred from key name and surrounding code)
- **Read-through or cache-aside** (does it check cache first, fall back to DB?)
- **How the retrieved value is used** — after a successful cache hit, read the code that uses the result. Identify:
  - Which specific **fields or properties** are accessed on the cached object (e.g. `.Type`, `["status"]`, `.Price`)
  - What **decisions or branches** those fields drive (e.g. "if `store.Type == "franchise"` routes to the franchise handler, otherwise uses the default handler"; "if `user.Active` is false, returns 403 immediately")
  - Any **further lookups** triggered by the cached data (e.g. "uses `store.WarehouseID` to query the warehouse table")

Record as `cache_patterns[]` = `{ system, key_pattern, ttl, what_is_cached, strategy, field_usage[] }`.

Print: `[<project>] Found <N> cache patterns`

---

## Step 4 — External service integrations

Find all outbound HTTP calls, gRPC calls, SDK calls, and message queue publish operations.

### 4a — HTTP / REST calls

Search for HTTP client instantiation and base URL assignments. Look for:
- **Go**: `http.NewRequest`, `resty.New()`, `http.Get(`, `.Do(req`
- **Node**: `axios.create(`, `fetch(`, `got(`, `request(`
- **PHP**: `Http::`, `Guzzle\Client`, `curl_exec(`
- **Python**: `requests.get(`, `httpx.Client(`, `aiohttp.ClientSession(`
- **Ruby**: `Faraday.new(`, `HTTParty.`, `Net::HTTP`

For each external call site, capture:
- Service name (infer from variable name or URL)
- Base URL or env var that holds it
- What endpoints are called (method + path pattern if visible)
- What data is sent / received (infer from payload or response parsing)

### 4b — gRPC calls

Find stub instantiation (`NewXxxClient(`, proto-generated client usage). Extract service name and methods called.

### 4c — Cloud SDK calls

Find SDK usage patterns:
- **SQS/SNS**: `sqs.SendMessage(`, `sns.Publish(`, `QueueUrl`, topic ARN
- **S3**: `s3.PutObject(`, `s3.GetObject(`, bucket name
- **SES/email**: `ses.SendEmail(`
- Other managed services

### 4d — Message queue consumers

Find subscription/consumer setups:
- **Go**: `sqs.ReceiveMessage(`, `ch.Consume(`, `kafka.NewReader(`
- **Node**: `consumer.subscribe(`, `channel.consume(`, `sqs.receiveMessage(`
- **Python**: `@app.task`, `channel.basic_consume(`, `consumer.subscribe(`
- **PHP**: `Queue::after(`, `handle(` in Job classes

For each consumer, capture: queue/topic name, what message it processes, what side effects it produces.

Record `external_integrations[]` = `{ type, service_name, url_or_queue, operations[], data_notes }`.

Print: `[<project>] Found <N> external integrations`

---

## Step 5 — Authentication & authorization analysis

Locate auth middleware, guards, token handlers, and session management:

- **Token type**: JWT (look for signing key env vars, `Claims` structs, `ParseWithClaims`), API keys (header names like `X-Api-Key`, `Authorization`), session cookies
- **What is stored in the token / session**: user ID, roles, tenant ID, scopes — read the claims struct or session serializer
- **Session storage**: if sessions are used, where are they stored (DB, Redis, in-memory)? Key pattern?
- **Auth enforcement**: which routes / middleware groups require auth (read route grouping code)
- **Authorization model**: role-based, permission-based, attribute-based, or none

Record `auth` = `{ mechanism, token_type, claims_or_session_data[], session_storage, enforcement_notes }`.

---

## Step 6 — Key data flows

Identify the 3–7 most significant operations the application performs. A "significant operation" is a business action that touches multiple data stores or external services.

Examples of significant operations:
- User registration / login
- Creating a core domain entity (order, product, shipment)
- Processing a webhook or queue message
- Generating a report or export

For each operation, trace what happens to data:
1. What data comes in (request body, message payload)
2. What is validated / enriched
3. What is read from cache (if any) — name the cache system, the key pattern, and the object retrieved
4. For each value retrieved from cache or DB: **which specific fields are accessed and what decisions they drive** — read the code after the fetch and follow what happens to each field. Look for `if`, `switch`, `match`, early `return`, or further lookups that branch on a retrieved value. Write these as concrete statements: *"the `store.type` field is checked — if `"franchise"` the request is forwarded to the franchise service, otherwise it is handled locally"*, *"if `user.blocked` is true, the handler returns 403 immediately"*, *"`order.warehouseID` is used to query the warehouse table for fulfilment routing"*.
5. What is read from DB (if cache miss or not cached) — name the table/collection and the fields selected or used after the query
6. What is written to DB — table name, key fields written
7. What is written to cache (if any) — key pattern and TTL
8. What external services are called and with what data
9. What events/messages are published

**Prose quality bar:** A good data flow narrative reads like: *"When placing an order, the handler reads the `store` object from Memcached under key `store:<storeID>`. It uses `store.type` to decide fulfilment: `"own"` stores fulfil directly from the local warehouse; `"marketplace"` stores forward the order to the Marketplace API. The order is then written to the `orders` table with status `pending`, and an `order.created` message is published to the `orders` SQS queue."* Vague statements like "fetches store data and processes the order" are not acceptable — name the fields, name the decisions.

Record `data_flows[]` = `{ operation, narrative }`.

---

## Step 7 — Rotate existing file

1. If `Architecture_old.md` exists in the project dir → delete it.
2. If `Architecture.md` exists → rename it to `Architecture_old.md`.
3. Proceed to write the new `Architecture.md`.

---

## Step 8 — Write Architecture.md

Create `<project-dir>/Architecture.md`:

```markdown
# Architecture — <project-name>

> Generated: <YYYY-MM-DD HH:MM:SS UTC>
> Stack: <primary_stack>

## Overview

<3–5 sentences. What does this system DO? What is its business purpose? Who uses it and for what? Is it an API server, a background worker, a data pipeline, a CLI? What domain does it operate in? Infer from entry points, README, route prefixes, model names.>

## Runtime Infrastructure

| Role | System | Details |
|---|---|---|
<One row per infrastructure dependency: database, cache, queue, search, storage. Include host/database name if discoverable from config.>

## Data Model

<For each entity: one paragraph or table. State what the entity represents, what it stores, where it is persisted, any notable constraints (soft deletes, tenant scoping, encryption). Include relationship descriptions in plain English. Omit fields that are generic boilerplate (id, created_at, updated_at) unless they have non-standard behavior.>

### <EntityName>

Stored in: <system and database/collection name>

| Field | Type | Notes |
|---|---|---|
<Only significant fields — skip generic timestamps unless notable>

Relationships: <plain English, e.g. "belongs to a User; has many OrderItems">

<Repeat for each entity>

## Caching Strategy

<If no caching is found, write "No caching detected." Otherwise describe each pattern.>

<For each cache pattern: what is cached, which system (Redis / Memcached), key pattern, TTL, the cache strategy (read-through, cache-aside, write-through), and — critically — what specific fields of the cached object are used downstream and what decisions they drive.>

Example of required specificity: *Store configuration is cached in Memcached under key `store:<storeID>` with a 10-minute TTL (cache-aside). On a hit, `store.type` determines fulfilment routing — `"franchise"` stores forward to the Franchise API while all others are handled locally. `store.warehouseID` is used to look up the dispatch warehouse. On a miss, the store row is fetched from the `stores` table and the cache is populated before continuing.*

## External Service Integrations

<For each external service: what it is, what data is sent to it, what data is received, and what triggers the call. Write as prose paragraphs, one per service.>

### <Service Name>

<Type: REST API / gRPC / SQS / S3 / etc.>

<What this service does for the application and what data flows to/from it.>

<Repeat for each integration>

## Message Queue & Event Patterns

<If no queues found, write "No message queue usage detected." Otherwise:>

### Produced Events

| Queue / Topic | Trigger | Payload summary |
|---|---|---|

### Consumed Events

| Queue / Topic | Handler | What it does |
|---|---|---|

## Authentication & Authorization

<Describe the auth mechanism, what the token or session contains, where sessions are stored if applicable, and how authorization is enforced (which routes require auth, what roles/permissions exist).>

## Key Data Flows

<One sub-section per significant operation. Write in plain English. Each narrative must name: the source of each data fetch (which cache key / which DB table), the specific fields read from the result, and what those fields decide. Avoid generic summaries — trace the data and the branching it causes.>

### <Operation Name>

<2–5 sentence narrative. Example of the required specificity: "The handler reads the `store` object from Memcached under key `store:<storeID>`. It checks `store.type`: if `"franchise"`, the request is forwarded to the Franchise API; otherwise it is fulfilled locally. The `order` row is written to the `orders` table with `status = "pending"`, and `store.warehouseID` is used to select the dispatch warehouse from the `warehouses` table.">

## Configuration

| Environment Variable | Purpose | Example / Default |
|---|---|---|
<Key variables that affect runtime behavior: DB DSN, cache host, queue names, external service URLs, feature flags, timeouts. Skip generic variables (PORT, HOST) unless notable.>
```

**Formatting rules:**
- Every claim must be grounded in code, config, or migration files actually read. Mark uncertain inferences with *(inferred)*.
- Omit sections that are empty (e.g. omit "Message Queue" if none found).
- Do NOT include a directory structure section.
- Do NOT include sections about coding patterns, architecture styles (MVC, hexagonal), or how to contribute.
- Keep the Overview factual; avoid marketing language.

---

## Step 9 — Summary

```
╔══════════════════════════════════════════════════╗
║        Architecture.md Generated                 ║
║  <project-name>                                  ║
╠══════════════════════════════════════════════════╣
║ Stack           : <primary_stack>                ║
║ Data models     : <N> entities                   ║
║ Cache patterns  : <N>                            ║
║ Ext integrations: <N>                            ║
║ Key data flows  : <N>                            ║
╠══════════════════════════════════════════════════╣
║ Previous arch   : saved as Architecture_old.md   ║
║                   (or: none to rotate)           ║
╠══════════════════════════════════════════════════╣
║ Generated       : <YYYY-MM-DD HH:MM UTC>         ║
╚══════════════════════════════════════════════════╝
```

---

## Key rules

- **Never modify source code, tests, or migrations.** Read-only with respect to application code.
- **No directory structure.** Architecture.md must not contain a directory tree or explain what each folder does.
- **No coding guidance.** Do not explain how to add features, how to write tests, or how the codebase is organized for developers.
- **Data-first.** Every section must answer a question about data: what is stored, where, how long, and why.
- **Evidence-based.** All claims must be traceable to a file you read. Mark inferences as *(inferred)*.
- **Always rotate.** Never overwrite Architecture.md directly — always rotate to Architecture_old.md first.
- **Infer names from config.** If the DB host is `orders-db.internal`, the database is likely named after the service. Use it.
