---
name: doctor
description: Use when the user runs /doctor — verifies project health by checking unit test coverage is above 80% and that 'docker compose up app' starts successfully with a passing healthcheck curl.
argument-hint: [project-directory]
---

# uzaak: Doctor

Diagnose a project's health: test coverage must be ≥ 80% and the app must respond to a healthcheck when run via `docker compose up app`.

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

Print: `[<project>] stack: <stack>`

## Step 1 — Measure test coverage

Determine the test framework:

| Stack | Condition | Framework |
|---|---|---|
| go | always | go_test |
| node | `jest.config.*` exists | jest |
| node | no jest config | npm_test |
| php | always | phpunit |
| python | always | pytest |
| ruby | always | rspec |

Run the coverage command:

| Framework | Command |
|---|---|
| go_test | `cd <dir> && go test -cover ./... 2>&1` |
| jest | `cd <dir> && npx jest --coverage --coverageReporters=text-summary 2>&1` |
| npm_test | `cd <dir> && npm test -- --coverage 2>&1` |
| phpunit | `cd <dir> && ./vendor/bin/phpunit --coverage-text 2>&1` |
| pytest | `cd <dir> && pytest --cov --cov-report=term-missing 2>&1` |
| rspec | `cd <dir> && bundle exec rspec --format progress 2>&1` |

### Coverage parsing rules

**go_test** — grep for `\d+\.\d+(?=% of statements)`, average all matches, truncate to int. Default 0.

**jest / npm_test** — grep for the `Lines` row, extract the first decimal number, truncate to int. Default 0.

**pytest** — grep for the `TOTAL` line, extract the number before `%` on the last match, use as int. Default 0.

**rspec** — grep for `\d+\.\d+(?=% covered)`, take first match, truncate to int. Default 0.

**phpunit** — grep for `Lines:` line, extract the percentage, truncate to int. Default 0.

Record:
- `coverage_pct`: integer percentage parsed from output
- `coverage_ok`: true if `coverage_pct >= 80`, false otherwise

Print: `[<project>] coverage: <coverage_pct>% — <OK / FAIL (below 80%)>`

## Step 2 — Verify docker compose healthcheck

### 2a — Find the liveness endpoint

Search the codebase to identify the liveness/healthcheck endpoint path. Check in order:
1. Route definitions (controllers, routers)
2. Swagger / OpenAPI specs
3. README or other docs

Common paths: `/health`, `/healthz`, `/ping`, `/status`, `/live`.

Read the host port for the `app` service from the docker-compose file.

### 2b — Start the app

Run:
```
docker compose up app -d
```

Wait for the container to start (check with `docker compose ps` until the app service is running or until it exits with an error).

Record:
- `app_started`: true if the `app` container reaches a running state, false if it fails to start or exits immediately

Print: `[<project>] docker compose up app: <OK / FAIL>`

### 2c — Run the healthcheck

Construct and run the curl command:
```
curl -s -o /dev/null -w "%{http_code}" http://localhost:<port>/<liveness-path>
```

Also record the full verbose version for the summary:
```
curl -v http://localhost:<port>/<liveness-path>
```

Record:
- `curl_command`: the exact curl command used (the verbose form)
- `curl_status`: the HTTP status code returned
- `compose_ok`: true if HTTP status is 2xx, false otherwise

Print: `[<project>] healthcheck: <curl_command> → <curl_status> — <OK / FAIL>`

### 2d — Tear down

Always run `docker compose down` (without `-v`) after the check, whether it passed or failed. Never leave containers running.

## Step 3 — Summary

Always print this summary at the end, regardless of outcome:

```
╔══════════════════════════════════════════╗
║           Project Health Report          ║
║              <project-name>              ║
╠══════════════════════════════════════════╣
║ Coverage : <coverage_pct>%  [OK / FAIL]  ║
║ Threshold: 80%                           ║
╠══════════════════════════════════════════╣
║ App start: docker compose up app [OK / FAIL] ║
╠══════════════════════════════════════════╣
║ Curl     : <curl_command>                ║
║ Response : HTTP <curl_status> [OK / FAIL]║
╠══════════════════════════════════════════╣
║ Overall  : HEALTHY / UNHEALTHY           ║
╚══════════════════════════════════════════╝
```

- **Overall HEALTHY**: `coverage_ok == true` AND `app_started == true` AND `compose_ok == true`
- **Overall UNHEALTHY**: either check failed

## Key rules

- **Never fix anything.** This skill only diagnoses — it does not modify source code, tests, or docker-compose.yml. If something fails, report it clearly and stop.
- **Always tear down.** Run `docker compose down` after every attempt, even if the curl fails.
- **Always print the curl command.** Print the exact curl command used, including the port and path.
- **Always print the summary.** Even if an earlier step crashes or times out, print whatever results were collected.
- Never use `docker compose down -v`.
