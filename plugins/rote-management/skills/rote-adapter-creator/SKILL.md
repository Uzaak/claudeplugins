---
name: rote-adapter-creator
description: Use when creating a new rote adapter for any system or API. Given a system name and URL, discovers the OpenAPI spec, creates the adapter with a comprehensive description, and verifies liveness. Handles internal services and any OpenAPI-compatible API.
---

# Create Rote Adapter

Streamlined adapter creation for any OpenAPI-compatible system. Less interactive than the full rote-adapter agent — sensible defaults, no unnecessary prompts.

## Step 0: Collect Inputs

You need two things before proceeding. If they are not present in the user's message, ask for both in a single `AskUserQuestion` call:

1. **System name** — e.g. `appex-checkout`, `product-api`, `my-service`
2. **Base URL** — e.g. `https://checkout-api.eks.qa.example.io/`
3. **Auth token** (optional) — if the API requires authentication, ask for the token value; otherwise skip

Do NOT proceed until you have `system_name` and `base_url`.

## Step 1: Derive Identifiers

From `system_name`, compute:

**Adapter ID** — lowercase, dashes only, no spaces:
```
appex-checkout  →  appex-checkout
My Service      →  my-service
product_api     →  product-api
```

**Display name** — title case, no dashes or underscores, space-separated words:
```
appex-checkout      →  Appex Checkout
product_api         →  Product Api
my-service-v2       →  My Service V2
```

## Step 2: Discover the OpenAPI Spec URL

Try each candidate URL with `curl -s -o /dev/null -w "%{http_code}" <url>` until you get HTTP 200. Stop at the first success.

Try in this order (normalize `base_url` to strip trailing slash first):
```
{base_url}/swagger/doc.json          ← Go/gin services (swaggo)
{base_url}/openapi.json
{base_url}/swagger.json
{base_url}/v3/api-docs               ← Spring Boot / Springfox
{base_url}/api-docs
{base_url}/swagger/v1/swagger.json
{base_url}/docs/openapi.json
```

If none return 200, ask the user to provide the spec URL directly.

**Store the discovered spec URL as `spec_url`.**

## Step 3: Dry-Run Analysis

```bash
rote adapter new <adapter_id> '<spec_url>' --dry-run
```

Parse the output and extract:
- Total operations count
- Detected toolsets (names + tool counts)
- Detected auth scheme (type + confidence)
- Detected base URL from spec

If dry-run fails (spec unreadable, 0 toolsets), stop and report the error.

## Step 4: Create the Adapter

Assemble the `--config-json`. Auth rules:

- **No token provided by user AND dry-run shows no auth or low confidence (<60%)** → omit auth block entirely
- **No token provided but dry-run shows auth required** → include the auth block from dry-run without a token (the user can add it later with `rote adapter update-auth`)
- **Token provided** → include full auth block and store the token first:
  ```bash
  rote token set <ADAPTER_ID_UPPER>_API_KEY <token_value>
  ```

Config JSON (no auth case):
```json
{"enable_parameter_cleaning": true}
```

Config JSON (with auth, e.g. bearer):
```json
{"auth": {"type": "bearer", "token_env": "MY_SERVICE_API_TOKEN"}, "enable_parameter_cleaning": true}
```

Run creation:
```bash
rote adapter new <adapter_id> '<spec_url>' --yes \
  --name '<display_name>' \
  --base-url '<base_url>' \
  --config-json '<config_json>'
```

If creation fails because the adapter already exists, stop and tell the user. Do NOT remove and recreate — that would orphan existing flows.

## Step 5: Generate and Apply Description

You are an API documentation expert. Using the dry-run output (operation count, toolset names, spec title, detected domain), write a description for this adapter following these rules:

1. 1–3 sentences maximum
2. Dense with nouns — include: resource types, domain, use cases, well-known names for this service
3. Optimised for semantic search — 50+ words preferred
4. No marketing language ("powerful", "seamless", "modern", etc.)
5. Include the base URL domain, operation count, and key resource types you can infer from the toolset names

**Apply it via CLI only — do NOT edit manifest.json directly:**
```bash
rote adapter set '<adapter_id>' description "<your description>"
```

## Step 6: Set Display Name

```bash
rote adapter set '<adapter_id>' name '<display_name>'
```

## Step 7: Generate and Install Subagent

```bash
rote adapter agent generate <adapter_id>
rote install skill --agents --agent <adapter_id>
```

If either command fails, note the failure but do not stop — the adapter is still usable without a subagent.

## Step 8: Liveness Check

Try common health endpoints in order. Stop at the first HTTP 200:

```bash
curl -s -o /dev/null -w "%{http_code}" <base_url>/health
curl -s -o /dev/null -w "%{http_code}" <base_url>/healthz
curl -s -o /dev/null -w "%{http_code}" <base_url>/health/live
curl -s -o /dev/null -w "%{http_code}" <base_url>/ping
curl -s -o /dev/null -w "%{http_code}" <base_url>/status
curl -s -o /dev/null -w "%{http_code}" <base_url>/ready
curl -s -o /dev/null -w "%{http_code}" <base_url>/actuator/health
```

Report the result:
- Found 200 → "Liveness OK at `<url>`"
- All returned non-200 → "No liveness endpoint responded — the API may require auth headers or the URL may differ"

## Step 9: Final Report

```
Adapter '<adapter_id>' created successfully.

  Display name:  <display_name>
  Base URL:      <base_url>
  Spec:          <spec_url>
  Operations:    <N> total (<toolset summary>)
  Auth:          <none | api_key_header | bearer | ...>
  Liveness:      <OK at /health | not found>
  Subagent:      <installed | failed>

Ready to use:
  rote <adapter_id>_probe '<your question>'

To configure later:
  rote adapter keys <adapter_id>
  rote adapter set <adapter_id> <key> <value>
  rote adapter update-auth <adapter_id>
```

## Rules

- Never edit `~/.rote/adapters/<id>/manifest.json` directly. Always use `rote adapter set`.
- Never guess or generate credential values. If a token is required and not provided, skip auth and note it in the report.
- If the adapter already exists, stop immediately — do not overwrite.
- Run each rote command separately. Do not chain or pipe.
- Auth is optional by default. Only include auth config when the user explicitly provides a token or when the spec clearly requires it.
