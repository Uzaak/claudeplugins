---
name: dockercomposefix
description: Create or fix docker-compose.yml so the app service starts and passes a liveness check via 'docker compose up app'. Preserves existing services and ports. Never touches Dockerfile unless the user explicitly allows it.
argument-hint: [project-directory]
---

# uzaak: Docker Compose Fix

Ensure a project can run via `docker compose up app` with a verified liveness check.

## Absolute constraints — read before doing anything

**Dockerfile is off-limits.** Do not read, create, or modify any Dockerfile unless the user has explicitly said you may. All fixes must be achieved through docker-compose.yml alone (env vars, volumes, build args, command overrides, healthcheck keys, etc.). If you believe a Dockerfile change is the only possible solution, stop and ask the user for permission first.

**Preserve everything that isn't broken.** The only thing you are allowed to fix is what is preventing the `app` service from starting and passing its liveness check. Every other service, port, volume, network, and environment variable in the existing docker-compose file must be left exactly as-is.

## Step 0 — Determine project directory

If an argument was provided, use it as the project directory. Otherwise use the current working directory.

Detect the stack by checking for these files (first match wins):

| File present | Stack |
|---|---|
| `go.mod` | go |
| `package.json` | node |
| `composer.json` | php |
| `requirements.txt` or `pyproject.toml` | python |
| `Gemfile` | ruby |
| (none) | unknown |

## Step 1 — Read the existing docker-compose file (if any)

If `docker-compose.yml` or `docker-compose.yaml` exists, read it fully before making any change. Note:
- Every service that is not `app` — treat as untouchable.
- Every port, volume, network, and env var that already exists — treat as intentional.
- Identify specifically what is wrong with the `app` service (or that it is missing entirely).

Only then decide the minimum change needed.

If no docker-compose file exists, create one from scratch with an `app` service appropriate for the detected stack. Do not invent extra services beyond what is clearly needed.

## Step 2 — Fix only the `app` service

Apply the smallest change that makes `app` runnable:

- Fix or add the `app` service definition.
- Set missing environment variables under `environment` or `env_file` — never in Dockerfile.
- Add or correct the `command` or `entrypoint` override if the image default is wrong.
- Add port mappings only for `app`; never change ports of other services.
- If `app` depends on other services, add a `depends_on` key — do not reconfigure those services.

When done, confirm that every other service in the file is byte-for-byte identical to what it was before.

### Port rules

- Do **not** change the host port of any service other than `app`.
- Only change `app`'s port if it explicitly conflicts with another service's host port.

## Step 3 — Find the liveness endpoint

Search the codebase to identify the liveness/healthcheck endpoint path. Check in order:
1. Route definitions (controllers, routers)
2. Swagger / OpenAPI specs
3. README or other docs

Common paths: `/health`, `/healthz`, `/ping`, `/status`, `/live`.

Read the host port for `app` from the docker-compose file.

## Step 4 — Start and verify

Run:
```
docker compose up app -d
```

Wait for the container to start, then curl the liveness endpoint:
```
curl -v http://localhost:<port>/<liveness-path>
```

Always print the exact curl command.

**2xx response:** healthy. Run `docker compose down` (no `-v`). Done.

**Failure or non-2xx:**
- Check logs: `docker compose logs app`
- Diagnose the root cause — missing env var, wrong port, dependency not ready, etc.
- Fix it in **docker-compose.yml only**. If you think you need to touch the Dockerfile, stop and ask the user first.
- Run `docker compose down`, then retry from the top of Step 4.
- Print the curl command on every attempt.
- Do not stop until the liveness check passes.

## Step 5 — Cleanup

Always run `docker compose down` (without `-v`) after a successful check or before exiting on failure. Never leave containers running.

## Key rules (summary)

- **Dockerfile: hands off** unless the user explicitly grants permission.
- **Other services: hands off** — only `app` may be changed.
- **Minimum viable change:** fix only what is broken, touch nothing else.
- Never use `docker compose down -v`.
- Always print every curl command attempted.
- The goal is a green 2xx liveness response, not just a started container.
