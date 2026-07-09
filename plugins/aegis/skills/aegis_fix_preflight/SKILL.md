---
name: aegis_fix_preflight
description: Use when the user runs /aegis_fix_preflight or asks to check delivery readiness and repair whatever is broken — build, app launch, unit/integration/load test failures, or CLAUDE.md gaps — using the aegis agents.
argument-hint: [optional focus or constraints]
---

# Aegis: Fix Preflight

Assess delivery readiness with the preflight agent, dispatch only the fixers its report demands, then re-run preflight to prove the fixes landed:

**preflight-slippy → routed fixers (code-kazuto / unit-test-deedee / integration-test-mayuri / load-test-toguro) → preflight-slippy**

## Rules — bind the whole run

- The orchestrator never fixes anything itself. It routes report findings to fixer agents by absolute artifact path and gates on `STATUS:` lines — the agent definitions carry all process.
- One UUID per run. Never regenerate it mid-run; agents correlate artifacts by it.
- One agent at a time, foreground (`run_in_background: false`). Every fixer mutates the same working tree, and each preflight run must see the tree the fixers left behind, so nothing is eligible to run concurrently.
- Maximum **2 remediation cycles** (triage → fix → re-run preflight). If issues remain after the second re-run, stop and report what remains — never loop further.
- `STATUS: FAILED` from any fixer ends the run. Never dispatch later fixers after a failure.
- A `skipped` suite (no `/integration` or `/stress` directory) is a **gap, not a failure**: report it, and dispatch the corresponding tester to create the missing suite only if the user's request asked for missing suites to be created.
- Dispatch prompts carry artifact file paths, never pasted artifact contents.
- Environment: `git`, `uuidgen`, and Docker (agents boot the app in isolated Compose projects).

## Step 1 — Set up and run preflight

1. `UUID=$(uuidgen | tr 'A-Z' 'a-z')`. Timestamps everywhere are `yyyy-mm-dd-hh-mm-ss`.
2. Resolve the artifact directory (worktree-safe): `$(git rev-parse --path-format=absolute --git-common-dir)/../.uzaak/`. Create it if absent and ensure `.uzaak/` is git-ignored.
3. Dispatch `aegis:preflight-slippy` (prompt recipe below). Its STATUS shape:
   `STATUS: OK | build=pass launch=pass integration=pass|fail|skipped stress=pass|fail|skipped claudemd=ok|incomplete`
   - Everything `pass`/`ok`/`skipped` with no gaps the user asked to fill → report ready, done. No fixers.
   - `STATUS: FAILED` or any `fail`/`incomplete` token → triage.
   - No parseable STATUS line → read the newest `.uzaak/preflight-<uuid>-*.md`; if its header `Status:` is not `OK` or the file is missing, treat the run as FAILED and stop.

## Step 2 — Triage the report into fixers

Read the preflight report artifact and route each issue:

| Issue in the report | Fixer | Input artifact |
|---|---|---|
| Build fails or app won't launch (incl. preflight `STATUS: FAILED` on those steps) | `aegis:code-kazuto` | fix spec (below) |
| `claudemd=incomplete` | `aegis:code-kazuto` | same fix spec — one deliverable per missing entry |
| Unit tests failing or broken, when the report surfaces them | `aegis:unit-test-deedee` | preflight report path |
| `integration=fail` | `aegis:integration-test-mayuri` | preflight report path |
| `stress=fail` | `aegis:load-test-toguro` | preflight report path |

**Fix spec** (only when code-kazuto is routed): consolidate all its items into one artifact at `.uzaak/spec-<uuid>-<ts>.md`, beginning with the standard aegis header (non-executable template — replace every placeholder):

```text
UUID: <uuid>
Agent: spec
Generated: <yyyy-mm-dd-hh-mm-ss>
Status: OK
```

followed by a **Deliverables** section: one ordered deliverable per issue, each quoting the exact evidence from the preflight report (error text, missing CLAUDE.md entry) and stating the observable fix ("build passes", "app responds on its healthcheck").

## Step 3 — Dispatch the routed fixers

Dispatch only the fixers routed in Step 2, in this order (repo-mutating agents on one tree):

1. `aegis:code-kazuto` → 2. `aegis:unit-test-deedee` → 3. `aegis:integration-test-mayuri` → 4. `aegis:load-test-toguro`

**Prompt recipe** — each dispatch prompt is exactly: (1) the run UUID, (2) each input artifact as an absolute path labeled by artifact type ("implementation spec", "preflight readiness report"), (3) the repo root to operate in, (4) one sentence stating the fix objective, naming the failing items from the report, (5) "Begin your reply with your STATUS line." Nothing else.

Gate each fixer on `STATUS: OK` before dispatching the next. Apply the same no-parseable-STATUS fallback as Step 1, against that agent's `.uzaak/<agent>-<uuid>-*.md` artifact.

## Step 4 — Verify by re-running preflight

Dispatch `aegis:preflight-slippy` again — same UUID, new timestamp.

- Clean report → done.
- Issues remain and this was cycle 1 → return to Step 2 with the new report.
- Issues remain after cycle 2 → stop, per the Rules.

## Step 5 — Report

Final message to the user: initial vs final preflight STATUS lines, each fixer dispatched with its outcome and commits, remaining issues or accepted gaps (`skipped` suites), and every artifact path.
