---
name: aegis_simple_code
description: Use when the user runs /aegis_simple_code or asks for coding work to be implemented and validated end-to-end by the aegis agents — from a raw coding request (no PRD or architecture exists; skip planning) or from existing implementation spec artifacts such as an aegis_wish_to_plan run's plans.
argument-hint: [coding request or spec path(s)]
---

# Aegis: Simple Code Pipeline

Run the aegis build agents per spec and the review agents once, under one shared run UUID:

**(code-kazuto → unit-test-deedee) per spec → technical-review-lucca → approve-samuel once**

With a single spec this is a pure 4-stage chain. With several specs the build loop repeats per spec in dependency order and the review pair runs once over the assembled result — a review dispatched mid-rollout judges an intermediate state against final expectations and manufactures false REJECTEDs.

## Rules — bind the whole run

- The orchestrator never implements, tests, or reviews. It scopes the request, routes artifacts by absolute path, and gates on `STATUS:` lines — the agent definitions carry all process.
- One UUID per run. Never regenerate it mid-run; agents correlate artifacts by it.
- One stage at a time, foreground (`run_in_background: false`). Build stages mutate the same working tree and the review certifies what they leave behind, so nothing is eligible to run concurrently. (Not an aegis-wide rule: read-only reviewers on the same UUID may parallelize in richer pipelines.)
- **Failure recovery is artifact-first.** On any stage failure — agent killed mid-flight, tool error, empty reply, or no parseable `STATUS:` line — read the newest `.uzaak/<agent>-<uuid>-*.md` **before** considering re-dispatch: header `Status: OK` means the work completed and only the chat reply was lost, so recover the stage's fields from the artifact and continue. Re-dispatch is the last resort.
- `STATUS: FAILED` at any stage ends the run. Never dispatch a later stage after a failure.
- `REJECTED` is a verdict, not a pipeline failure. Report it as the outcome of a successful run.
- Dispatch prompts carry artifact file paths, never pasted artifact contents.
- Environment: `git`, `uuidgen`, and Docker (agents boot the app in isolated Compose projects).

## Step 0 — Understand the request

- No task provided → ask for one.
- The request may be a raw coding request **or** one or more existing implementation spec paths (e.g. `plan-<uuid>-*.md` artifacts from an aegis_wish_to_plan run). Existing specs → skip spec-writing in Step 1.3 and reuse their UUID as the run UUID; several specs → order them by implementation dependency before dispatching.
- If scope or expected behavior is ambiguous, ask at most one round of clarifying questions **now** — every downstream agent operates in no-questions mode.
- Skim the target codebase enough to name real files, modules, and conventions.

## Step 1 — Set up the run

1. `UUID=$(uuidgen | tr 'A-Z' 'a-z')` — or the UUID reused from supplied specs. Timestamps everywhere are `yyyy-mm-dd-hh-mm-ss`.
2. Resolve the artifact directory (worktree-safe): `$(git rev-parse --path-format=absolute --git-common-dir)/../.uzaak/`. Create it if absent and ensure `.uzaak/` is git-ignored.
3. *(Raw request only)* Write the **implementation spec** to `.uzaak/spec-<uuid>-<ts>.md`. It must begin with the standard aegis artifact header (non-executable template — replace every placeholder):
   ```text
   UUID: <uuid>
   Agent: spec
   Generated: <yyyy-mm-dd-hh-mm-ss>
   Status: OK
   ```
   followed by two sections:
   - **Deliverables** — ordered, each a single testable unit: file paths, exact behavior, validation rules, signatures and data structures where non-obvious.
   - **Architecture Notes** — system responsibilities and boundaries, contracts (request/response shapes, sync/async), data models, and decisions with reasoning. When no separate architecture document exists, this section is the run's architecture baseline (see the stage-3 architecture input rule).
4. Write the **pipeline state note** to `.uzaak/state-<uuid>.md` (same header, `Agent: state`): a short bullet list of currently-expected conditions ("cmd/server won't build until spec 3 lands"; "providers/*.json arrive with spec 2"). Update it between stages — add facts as they become true, delete them when they stop being expected. A single-spec run with nothing to note keeps it empty.

## Step 2 — Dispatch the pipeline

One Agent tool call per stage, per the Rules above. Stages 1–2 repeat per spec in dependency order; stages 3–4 run once, after the last spec's build loop completes.

| # | subagent_type | Prompt carries | Gate to proceed |
|---|---|---|---|
| 1 | `aegis:code-kazuto` | UUID + spec path (labeled "implementation spec") + state note path | `STATUS: OK` with `build=pass launch=pass` |
| 2 | `aegis:unit-test-deedee` | UUID + "codebase = current working tree" + state note path | `STATUS: OK` with `coverage` ≥ 85 — unless skipped (below) |
| 3 | `aegis:technical-review-lucca` | UUID + architecture input (below) + state note path | `STATUS: OK` |
| 4 | `aegis:approve-samuel` | UUID + technical-review report path (labeled "technical review report") | `STATUS: OK` (any verdict) |

**Stage-2 skip gate:** read `src_files=` from code-kazuto's STATUS line (fall back to the file list in its report artifact). `src_files=0` — the spec touched only data, config, docs, or compose files — means skip stage 2 for that spec and record "unit-test: skipped — no source changes".

**Stage-3 architecture input:** glob `.uzaak/architecture-<uuid>-*.md` for the run UUID, then check the spec headers/bodies for a predecessor run's architecture artifact. Found one → pass it labeled "architecture document", plus the spec path(s) labeled "implementation spec (supporting detail)". Found none → pass the spec labeled "implementation spec — its Architecture Notes section is the architecture baseline for this run".

**Interim checkpoint (optional, large runs only):** on a many-spec run where mid-run assurance is genuinely wanted, insert an explicit lucca checkpoint at a meaningful milestone — a deliberate choice stated in the run report, never a per-spec default. Its prompt must carry the state note path so expected in-flight gaps are context, not findings.

**Dispatch prompt recipe** — each prompt is exactly: (1) the run UUID, (2) each input artifact as an absolute path labeled by artifact type, including the state note path labeled "pipeline state note — expected conditions, not defects", (3) the repo root to operate in, (4) "Begin your reply with your STATUS line." Nothing else.

## Step 3 — Gate on STATUS

- Parse the first `STATUS:` line of each reply and record the artifact path the agent reports.
- Stage died, errored, or produced no parseable STATUS → artifact-first recovery per the Rules, against that agent's `.uzaak/<agent>-<uuid>-*.md`.
- `STATUS: FAILED` (from the reply or a recovered artifact) → stop per the Rules. Report the failed stage, its `reason=`, and its artifact path.

## Step 4 — Report the verdict

Final message to the user: the verdict (`APPROVED` / `APPROVED_WITH_DEBT` / `REJECTED`), blocking issues or debt items, per-spec build outcomes (coverage achieved, or "unit-test skipped — no source changes"), commits made, and every artifact path.

- The verdict certifies only the **technical** dimension — approve-samuel will correctly list product, blue-team, and red-team as uncovered. State this explicitly.
- This version does not auto-loop on `REJECTED`: present the blocking issues, and if the user wants a fix cycle, write a spec addendum artifact (same UUID, new timestamp) containing the blocking issues and re-run the build loop for the affected spec(s), then the review pair.
