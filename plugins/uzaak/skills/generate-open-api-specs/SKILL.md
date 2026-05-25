---
name: generate-open-api-specs
description: Use when the user runs /generate-open-api-specs — reads the project's route definitions and handler code, optionally merges existing Swagger documentation, and writes a complete OpenAPI 3.0 spec to open-api.specs at the project root.
argument-hint: [project-directory]
---

# uzaak: Generate OpenAPI Specs

Read all route definitions and handler code, merge any existing Swagger documentation, and produce a complete `open-api.specs` file in OpenAPI 3.0 YAML format at the project root.

Print: `[<project>] Starting OpenAPI spec generation...`

---

## Step 0 — Determine project directory

If an argument was provided, use it as the project directory. Otherwise use the current working directory.

Infer the application name from the project directory name (last path segment).

---

## Step 1 — Detect stack and routing framework

### 1a — Stack detection

| File present | Stack |
|---|---|
| `go.mod` | go |
| `package.json` | node |
| `composer.json` | php |
| `requirements.txt` or `pyproject.toml` | python |
| `Gemfile` | ruby |
| (none) | unknown |

### 1b — Routing framework detection

Read the primary dependency file and identify the HTTP routing framework:

| Stack | Framework indicators | Route file patterns |
|---|---|---|
| **go** | `github.com/gin-gonic/gin` → **gin**; `github.com/labstack/echo` → **echo**; `github.com/go-chi/chi` → **chi**; `github.com/gorilla/mux` → **mux**; `net/http` only → **stdlib** | `*router*.go`, `*routes*.go`, `main.go`, `cmd/*/main.go` |
| **node** | `express` → **express**; `fastify` → **fastify**; `@nestjs/core` → **nestjs**; `koa` → **koa** | `*router*`, `*routes*`, `app.js`, `server.js`, `index.js`, `src/**/*.controller.*` |
| **php** | `laravel/framework` → **laravel**; `symfony/routing` → **symfony** | `routes/api.php`, `routes/web.php`, `config/routes.yaml`, `src/Controller/` |
| **python** | `flask` → **flask**; `fastapi` → **fastapi**; `django` → **django**; `starlette` → **starlette** | `app.py`, `main.py`, `*views.py`, `*router*.py`, `urls.py` |
| **ruby** | `rails` → **rails**; `sinatra` → **sinatra** | `config/routes.rb`, `app/controllers/` |

Record `framework`.

Print: `[<project>] Stack: <stack>, Framework: <framework>`

---

## Step 2 — Check for existing OpenAPI / Swagger documentation

Search these locations in order:

1. `swagger.yaml`, `swagger.json`, `openapi.yaml`, `openapi.json` (project root)
2. `docs/swagger.yaml`, `docs/swagger.json`, `docs/openapi.yaml`, `docs/openapi.json`
3. `api/swagger.yaml`, `api/openapi.yaml`
4. **Go (swaggo)**: `docs/docs.go`, `docs/swagger.yaml` — read both; the YAML is the spec, `docs.go` may contain inline annotations
5. **Node**: JSDoc `@swagger` or `@openapi` block comments in route files
6. **Python FastAPI**: the app auto-generates a spec at `/openapi.json` at runtime — read source for `@router.get`, `@router.post` decorators and Pydantic models instead
7. **Python (drf-spectacular / drf-yasg)**: `schema.yml`, `openapi-schema.yml`, or `@extend_schema` decorators
8. **PHP (L5-Swagger / zircote)**: `@OA\` annotation comments in controller files

If an existing spec file is found:
- Record `existing_spec_path` and `existing_spec_format` (yaml/json)
- Read it in full — it will be used as the **base** to merge discovered endpoints into
- Print: `[<project>] Found existing spec: <path>`

If no existing spec file is found:
- Print: `[<project>] No existing spec found — building from scratch`
- Set `existing_spec = null`

---

## Step 3 — Discover all routes

Read route definition files identified in Step 1b. Extract every route.

### 3a — Route extraction by framework

**gin (Go):**
Search for `r.GET(`, `r.POST(`, `r.PUT(`, `r.PATCH(`, `r.DELETE(`, `r.OPTIONS(`, `r.HEAD(`, `.Group(`. For groups, concatenate the group prefix with child paths.

**echo (Go):**
Search for `e.GET(`, `e.POST(`, `.Group(`, `g.GET(` etc. Same group-prefix logic.

**chi / mux / stdlib (Go):**
Search for `r.Get(`, `r.Post(`, `mux.HandleFunc(`, `http.HandleFunc(`, `.Route(`, `.Mount(`.

**express (Node):**
Search for `router.get(`, `router.post(`, `app.get(`, `app.post(`, `router.use(`. Follow `require`/`import` chains for sub-routers. For `router.use('/prefix', subRouter)`, prefix all sub-router paths.

**nestjs (Node):**
Search for `@Controller(`, `@Get(`, `@Post(`, `@Put(`, `@Patch(`, `@Delete(`. Combine controller prefix with method decorator path.

**fastify (Node):**
Search for `fastify.get(`, `fastify.post(`, `fastify.register(`. Follow plugin registrations.

**laravel (PHP):**
Read `routes/api.php` and `routes/web.php`. Look for `Route::get(`, `Route::post(`, `Route::apiResource(`, `Route::group(`. For `apiResource`, expand to the standard RESTful routes (index, store, show, update, destroy).

**symfony (PHP):**
Read `config/routes.yaml` and `@Route(` annotations in controller files.

**flask (Python):**
Search for `@app.route(`, `@blueprint.route(`, `@api.route(`. Extract `methods=[...]` argument.

**fastapi (Python):**
Search for `@router.get(`, `@router.post(`, `@app.get(`, `@app.post(` etc. Note `response_model=` argument.

**django (Python):**
Read `urls.py` files (all of them, including included url confs). Extract `path(`, `re_path(`, `url(`. For viewsets, expand to standard CRUD routes.

**rails (Ruby):**
Read `config/routes.rb`. Parse `resources :x`, `namespace :x`, `scope :x`, `get`, `post`, `put`, `patch`, `delete` declarations. Expand `resources` to the standard 7 RESTful routes (index, create, new, edit, show, update, destroy). `api_only` skips `new` and `edit`.

For **each** discovered route record:
- `method`: HTTP verb (GET, POST, PUT, PATCH, DELETE)
- `path`: full path with parameter placeholders in `{param}` format (convert `:param` → `{param}`, `<param>` → `{param}`)
- `handler`: function or controller action name
- `tags`: infer from path prefix or controller name (e.g. `/users/` → `tags: [users]`)

Record `routes[]` = `{ method, path, handler, tags[] }`.

### 3b — Health check endpoint discovery (always run, regardless of framework results)

Independently of the framework scan above, search the entire codebase for health check and liveness endpoints. These are often registered outside the main router or in middleware/server setup code and are easy to miss.

Search for the following path strings in all `.go`, `.js`, `.ts`, `.py`, `.rb`, `.php` files:

> `/health`, `/healthz`, `/ping`, `/status`, `/live`, `/liveness`, `/ready`, `/readiness`, `/actuator/health`, `/_health`, `/api/health`, `/api/ping`

Also search for handler function names: `health`, `healthCheck`, `healthz`, `ping`, `liveness`, `readiness`, `status`.

For each found health check endpoint:
- Add it to `routes[]` if not already present
- Tag it as `tags: [health]`
- Mark it as `requires_auth: false`
- The response schema is always: HTTP 200 with `{ "status": "ok" }` or equivalent (use what the code returns; if not determinable, use `{ status: string }`)

Print: `[<project>] Discovered <N> routes (<M> health check endpoints included)`

---

## Step 4 — Analyse handlers for request / response shapes

For each route, read the handler function body. Extract:

### 4a — Path parameters

Parameters already captured from the path template (e.g. `{id}`, `{slug}`). Set `in: path`, `required: true`. Infer type from name: `id`/`*_id` → `integer`, `uuid` → `string (format: uuid)`, others → `string`.

### 4b — Query parameters

**Go**: look for `c.Query(`, `c.DefaultQuery(`, `r.URL.Query().Get(`  
**Node**: look for `req.query.`, `c.query(` (fastify)  
**PHP**: look for `$request->query(`, `$request->input(`  
**Python**: look for function parameters with default values in FastAPI routes, `request.args.get(` in Flask, `request.GET.get(` in Django  
**Ruby**: look for `params[:x]` where `x` is not a route segment

For each query parameter: name, type (infer from usage), required (true if no default), description.

### 4c — Request body

**Go**: look for `c.ShouldBindJSON(`, `json.NewDecoder(r.Body).Decode(`, `c.Bind(`. Read the struct being bound — extract its JSON field names and types from struct tags.  
**Node**: look for `req.body.`, destructuring from `req.body`. Look for validation schema (Joi, Zod, class-validator) to get field types.  
**PHP**: look for `$request->validated()`, FormRequest class `rules()` method, or direct `$request->input(` calls.  
**Python FastAPI**: read the Pydantic model used as the body parameter. Extract all `Field` definitions.  
**Python Flask/Django**: look for serializer classes (`serializers.Serializer` fields) or direct `request.json.get(` calls.  
**Ruby**: look for `params.require(:x).permit(...)` — the permitted keys form the request body.

### 4d — Response body

**Go**: look for `c.JSON(`, `json.NewEncoder(w).Encode(`, `c.ShouldBindJSON(`. Read the struct or map being serialized.  
**Node**: look for `res.json(`, `reply.send(`. Read the object shape.  
**PHP**: look for `return response()->json(`, JsonResource classes, API resources (`toArray` method).  
**Python FastAPI**: read `response_model=` decorator argument — that Pydantic model defines the response.  
**Python Flask**: look for `return jsonify(`, `return schema.dump(`.  
**Django**: look for `return Response(serializer.data)` — read the serializer fields.  
**Ruby**: look for `render json:` — read the object or serializer being rendered.

### 4e — Authentication requirement

Check whether the route is inside an auth middleware group or has an auth decorator:
- **Go**: route is inside a group with JWT middleware, `AuthRequired` middleware, or similar
- **Node**: route has `authenticate`, `verifyToken`, `passport.authenticate(` middleware
- **PHP**: route is inside `auth:api` or `auth:sanctum` group
- **Python**: route has `Depends(get_current_user)` or `@login_required` or `permission_classes`
- **Ruby**: route action has `before_action :authenticate_user!` or `before_action :require_auth`

Record `requires_auth: true/false`.

For each route, update: `routes[i].parameters[]`, `routes[i].request_body`, `routes[i].response_schema`, `routes[i].requires_auth`.

---

## Step 5 — Extract reusable schemas

Collect all structs / models / Pydantic models / serializers referenced across handlers. Deduplicate. These become `components/schemas` in the output.

For each schema:
- Name: use the struct/class/model name
- Properties: field name, type (map language types → OAS types: `string`, `integer`, `number`, `boolean`, `array`, `object`), description (from struct tags or docstrings), required (non-pointer / non-nullable fields)

---

## Step 6 — Detect auth scheme

From Step 1c config discovery or middleware inspection:

| Pattern | OAS security scheme |
|---|---|
| `Authorization: Bearer <jwt>` header | `bearerAuth` (http, bearer, JWT) |
| `X-Api-Key` or `Authorization: ApiKey` | `apiKeyAuth` (apiKey, header) |
| Cookie-based session | `cookieAuth` (apiKey, cookie) |
| OAuth2 / OIDC | `oauth2` |
| No auth detected | omit `security` |

---

## Step 7 — Merge with existing spec (if found in Step 2)

If `existing_spec != null`:

1. Load the existing spec as the base document.
2. For each route discovered in Steps 3–4, check if that `method + path` already exists in the base spec.
   - **Exists**: merge — prefer the existing spec's `summary`, `description`, and any manually written `example` values; use discovered parameters and schemas to fill in gaps (missing parameters, missing request/response schemas).
   - **Does not exist**: add it as a new path entry.
3. Merge `components/schemas` — add new schemas discovered; do not overwrite schemas that already exist in the base spec.
4. Preserve any manually written fields: `externalDocs`, `x-*` extensions, `tags[].description`, server variables.

If `existing_spec == null`: build the spec entirely from discovered data.

---

## Step 8 — Write open-api.specs

**Always write the file.** Even if no routes were found, `open-api.specs` must be created. A missing file is never an acceptable outcome.

### 8a — Determine mode

| Condition | Mode |
|---|---|
| `routes[]` has at least one non-health-check entry | **normal** — full spec |
| `routes[]` has only health check entries | **health-only** — spec with health paths + no-business-endpoints note |
| `routes[]` is empty (no routes found at all) | **empty** — spec with no paths + explanation |

### 8b — Structure for empty mode (no routes at all)

If mode is **empty**, write:

```yaml
openapi: "3.0.3"

info:
  title: <project-name>
  version: "1.0.0"
  description: |
    No HTTP endpoints were detected in this project through static analysis.

    This may mean the project is a background worker, a CLI tool, a library,
    or a message-queue consumer that does not expose an HTTP interface.
    If endpoints exist, they may be registered dynamically or generated at
    runtime and cannot be discovered through static analysis alone.

x-no-endpoints: true

paths: {}
```

### 8c — Structure for health-only mode

If mode is **health-only**, write the full spec structure below but add to the `info.description`:

```
NOTE: No business endpoints were detected. Only infrastructure/health endpoints are documented.
This service may be a background worker or internal component without a public API surface.
```

### 8d — Normal and health-only spec structure

Write a single YAML file to `<project-dir>/open-api.specs`.

Structure:

```yaml
openapi: "3.0.3"

info:
  title: <project-name>
  version: "1.0.0"
  description: |
    <2–3 sentence description of the API inferred from the codebase>

servers:
  - url: <base URL from config if found, otherwise http://localhost:{port}>
    description: Local development

tags:
  - name: <tag>
    description: ""
  # one entry per unique tag

paths:
  /path/{param}:
    get:
      summary: <inferred from handler name or route, e.g. "Get user by ID">
      tags: [<tag>]
      security:         # omit if requires_auth == false
        - bearerAuth: []
      parameters:
        - name: param
          in: path
          required: true
          schema:
            type: string
        - name: filter
          in: query
          required: false
          schema:
            type: string
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/EntityName"
        "400":
          description: Bad request
        "401":
          description: Unauthorized     # only if requires_auth == true
        "404":
          description: Not found        # only for routes with {id} parameters
        "500":
          description: Internal server error
    post:
      summary: <inferred>
      tags: [<tag>]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/CreateEntityRequest"
      responses:
        "201":
          description: Created
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/EntityName"
        "400":
          description: Bad request
        "500":
          description: Internal server error

components:
  schemas:
    EntityName:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
      required:
        - id
        - name

  securitySchemes:
    bearerAuth:           # only if JWT auth detected
      type: http
      scheme: bearer
      bearerFormat: JWT
    apiKeyAuth:           # only if API key auth detected
      type: apiKey
      in: header
      name: X-Api-Key
```

**YAML formatting rules:**
- Use 2-space indentation throughout.
- Quote strings that contain `:`, `#`, or special characters.
- Use `$ref` for any schema referenced more than once.
- Include standard error responses (400, 401, 404, 500) where semantically appropriate — do not add them blindly to every route.
- If a request/response shape cannot be determined from the code, use `schema: {}` with a comment `# TODO: schema not determinable from static analysis`.
- Do not include example values unless they were present in existing documentation.

---

## Step 9 — Summary

```
╔══════════════════════════════════════════════════╗
║          OpenAPI Spec Generated                  ║
║  <project-name>                                  ║
╠══════════════════════════════════════════════════╣
║ Stack/Framework : <stack> / <framework>          ║
║ Mode            : <normal / health-only / empty> ║
║ Routes found    : <N> (<M> health check)         ║
║ Schemas         : <N> components                 ║
╠══════════════════════════════════════════════════╣
║ Source          : <built from scratch /          ║
║                   merged with <existing_path>>   ║
╠══════════════════════════════════════════════════╣
║ Output          : open-api.specs                 ║
║ Generated       : <YYYY-MM-DD HH:MM UTC>         ║
╚══════════════════════════════════════════════════╝
```

If any routes had undeterminable schemas, list them:
```
⚠ Schemas not determined (static analysis limitation):
  - POST /some/path — request body unknown
  - GET /other/path — response schema unknown
```

---

## Key rules

- **Never modify source code.** Read-only with respect to application code.
- **Merge, never overwrite.** When an existing spec exists, preserve manually written summaries, descriptions, and examples. Fill gaps only.
- **All paths in `{param}` format.** Convert `:param` (Express/Rails) and `<param>` (Flask) to `{param}` in the output.
- **One file, one format.** Output is always YAML, always named `open-api.specs`, always at the project root.
- **Mark unknowns.** Use `schema: {}` with a `# TODO:` comment rather than guessing a shape you cannot confirm.
- **Infer summaries from handler names.** `GetUserByID` → "Get user by ID". `CreateOrder` → "Create order". Avoid generic labels like "Handler" or "Endpoint".
- **Always write the output.** The file must be written regardless of how many routes were found — zero routes, only health checks, or a full API. A missing `open-api.specs` is never acceptable.
- **Always scan for health checks separately.** Health check endpoints are registered outside the main router in many projects. Step 3b must always run, even when the framework scan found routes.
- **Explain when empty.** If no routes were found, the spec's `info.description` must clearly state this and suggest why (worker, CLI, library, dynamic registration). Use `x-no-endpoints: true` to make the absence machine-readable.
