---
name: aegis_simple_code
description: Use when the user runs /aegis_simple_code or asks for a coding request to be implemented and validated end-to-end by the aegis agents, and no PRD or architecture document exists for the work (skip the planning phase).
argument-hint: [coding request]
---

# Aegis: Simple Code Pipeline

Run four aegis agents in strict sequence under one shared run UUID:

**code-kazuto → unit-test-deedee → technical-review-lucca → approve-samuel**

## Rules — bind the whole run

- The orchestrator never implements, tests, or reviews. It scopes the request, routes artifacts by absolute path, and gates on `STATUS:` lines — the agent definitions carry all process.
- One UUID per run. Never regenerate it mid-run; agents correlate artifacts by it.
- One stage at a time, foreground (`run_in_background: false`). This pipeline is a pure dependency chain and stages 1–2 mutate the same working tree, so nothing is eligible to run concurrently. (Not an aegis-wide rule: read-only reviewers on the same UUID may parallelize in richer pipelines.)
- `STATUS: FAILED` at any stage ends the run. Never dispatch a later stage after a failure.
- `REJECTED` is a verdict, not a pipeline failure. Report it as the outcome of a successful run.
- Dispatch prompts carry artifact file paths, never pasted artifact contents.
- Environment: `git`, `uuidgen`, and Docker (agents boot the app in isolated Compose projects).

## Step 0 — Understand the request

- No task provided → ask for one.
- If scope or expected behavior is ambiguous, ask at most one round of clarifying questions **now** — every downstream agent operates in no-questions mode.
- Skim the target codebase enough to name real files, modules, and conventions.

## Step 1 — Set up the run

1. `UUID=$(uuidgen | tr 'A-Z' 'a-z')`. Timestamps everywhere are `yyyy-mm-dd-hh-mm-ss`.
2. Resolve the artifact directory (worktree-safe): `$(git rev-parse --path-format=absolute --git-common-dir)/../.uzaak/`. Create it if absent and ensure `.uzaak/` is git-ignored.
3. Write the **implementation spec** to `.uzaak/spec-<uuid>-<ts>.md`. It must begin with the standard aegis artifact header (non-executable template — replace every placeholder):
   ```text
   UUID: <uuid>
   Agent: spec
   Generated: <yyyy-mm-dd-hh-mm-ss>
   Status: OK
   ```
   followed by two sections:
   - **Deliverables** — ordered, each a single testable unit: file paths, exact behavior, validation rules, signatures and data structures where non-obvious.
   - **Architecture Notes** — system responsibilities and boundaries, contracts (request/response shapes, sync/async), data models, and decisions with reasoning.

   The spec does double duty: the code agent consumes it as its implementation spec; the technical review consumes it as the architecture document.

## Step 2 — Dispatch the pipeline

One Agent tool call per stage, per the Rules above.

| # | subagent_type | Prompt carries | Gate to proceed |
|---|---|---|---|
| 1 | `aegis:code-kazuto` | UUID + spec path (labeled "implementation spec") | `STATUS: OK` with `build=pass launch=pass` |
| 2 | `aegis:unit-test-deedee` | UUID + "codebase = current working tree" | `STATUS: OK` with `coverage` ≥ 85 |
| 3 | `aegis:technical-review-lucca` | UUID + spec path (labeled "architecture document") | `STATUS: OK` |
| 4 | `aegis:approve-samuel` | UUID + technical-review report path (labeled "technical review report") | `STATUS: OK` (any verdict) |

**Dispatch prompt recipe** — each prompt is exactly: (1) the run UUID, (2) each input artifact as an absolute path labeled by artifact type, (3) the repo root to operate in, (4) "Begin your reply with your STATUS line." Nothing else.

## Step 3 — Gate on STATUS

- Parse the first `STATUS:` line of each reply and record the artifact path the agent reports.
- `STATUS: FAILED` → stop per the Rules. Report the failed stage, its `reason=`, and its artifact path.
- No parseable STATUS line → read the newest `.uzaak/<agent>-<uuid>-*.md`; if its header `Status:` is not `OK` or the file is missing, treat the stage as FAILED.

## Step 4 — Report the verdict

Final message to the user: the verdict (`APPROVED` / `APPROVED_WITH_DEBT` / `REJECTED`), blocking issues or debt items, coverage achieved, commits made, and every artifact path.

- The verdict certifies only the **technical** dimension — approve-samuel will correctly list product, blue-team, and red-team as uncovered. State this explicitly.
- This version does not auto-loop on `REJECTED`: present the blocking issues, and if the user wants a fix cycle, write a spec addendum artifact (same UUID, new timestamp) containing the blocking issues and re-run from stage 1.
