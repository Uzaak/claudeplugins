---
name: aegis_wish_to_plan
description: Use when the user runs /aegis_wish_to_plan or asks to turn a raw wish, idea, or feature request into an implementation-ready plan using the aegis planning agents — planning only, no code is written.
argument-hint: "[wish or path to notes/transcript] [default|silent]"
---

# Aegis: Wish to Plan

Turn a raw wish into implementation-ready specs by running the four aegis planning agents:

**prd-chihiro → architecture-kayaba → deliverables-kenshin → plan-lawliet (one per system, fan-out)**

## Rules — bind the whole run

- The orchestrator never writes the PRD, architecture, deliverables, or specs itself. It routes artifacts by absolute path and gates on `STATUS:` lines — the agent definitions carry all process.
- One UUID per run. Never regenerate it mid-run; agents correlate artifacts by it.
- Stages 1–3 run sequentially, foreground — each consumes the previous artifact. Stage 4 (plan-lawliet) may fan out — lawliet is read-only and parallel-safe across systems on the same UUID — but **in waves of at most 3 concurrent dispatches**, each wave gated before the next. If the session has already consumed a large share of its budget (long conversation, prior heavy runs), run stage 4 sequentially instead: a batch killed by the session limit costs more in re-dispatch and recovery triage than a staggered rollout.
- **Failure recovery is artifact-first.** On any agent failure — killed mid-flight, tool error, empty reply, or no parseable `STATUS:` line — read the newest `.uzaak/<agent>-<uuid>-*.md` **before** considering re-dispatch: header `Status: OK` means the work completed and only the chat reply was lost. Re-dispatch is the last resort.
- The operating mode (Default or Silent) binds only prd-chihiro and architecture-kayaba — the other two never ask questions. Every dispatch to those two states the mode explicitly.
- **Question relay (Default mode):** a reply from chihiro or kayaba that does not begin with `STATUS:` is a round of clarifying questions. Relay them to the user verbatim, then return the answers to the **same agent** via SendMessage so it keeps its context. Maximum two rounds per agent; on a third questioning reply, respond "No further answers — proceed and document your assumptions."
- **Silent mode:** never relay questions; agents resolve ambiguity themselves and document assumptions.
- `STATUS: FAILED` from any agent ends the run. Report the stage, its `reason=`, and its artifact path.
- Dispatch prompts carry artifact file paths, never pasted artifact contents.
- Environment: `git` and `uuidgen`. No Docker needed — planners never boot the app.

**Dispatch prompt recipe** — each prompt is exactly: (1) the run UUID, (2) the operating mode (chihiro and kayaba only), (3) each input artifact as an absolute path labeled by artifact type (including a pipeline state note path labeled "pipeline state note — expected conditions, not defects", when the orchestrator maintains one), (4) inline parameters where the agent requires them (systems + languages list; target system name), (5) the repo root, (6) "Begin your reply with your STATUS line" — for chihiro and kayaba in Default mode, "…or with your clarifying questions." Nothing else.

## Step 0 — Capture the wish and choose the mode

- No wish provided → ask for one. Accept freeform text, file paths, or transcripts.
- Mode: if the invocation states it ("silent", "don't ask questions", "interactive") → use it. Otherwise ask the user one question: **Default** (agents may ask up to two rounds of clarifying questions — better-grounded documents) or **Silent** (fully autonomous — every ambiguity becomes a documented assumption).

## Step 1 — Set up the run

1. `UUID=$(uuidgen | tr 'A-Z' 'a-z')`. Timestamps everywhere are `yyyy-mm-dd-hh-mm-ss`.
2. Resolve the artifact directory (worktree-safe): `$(git rev-parse --path-format=absolute --git-common-dir)/../.uzaak/`. Create it if absent and ensure `.uzaak/` is git-ignored.
3. Write the wish to `.uzaak/wish-<uuid>-<ts>.md` — the user's input verbatim plus any files they pointed at, beginning with the standard aegis header (non-executable template — replace every placeholder):
   ```text
   UUID: <uuid>
   Agent: wish
   Generated: <yyyy-mm-dd-hh-mm-ss>
   Status: OK
   ```

## Step 2 — PRD

Dispatch `aegis:prd-chihiro` with the wish artifact (labeled "raw input"). Apply the question-relay rule. Gate: `STATUS: OK`. Record the PRD path and its `open_questions=` / `evidence=` values for the final report.

## Step 3 — Architecture

1. Derive the **systems + languages list** kayaba requires: read the PRD, inspect the repo for the languages actually in use. In Default mode, confirm the list with the user if more than one reading is plausible; in Silent mode, infer and say so in the dispatch prompt.
2. Dispatch `aegis:architecture-kayaba` with the PRD path (labeled "PRD") and the systems + languages list inline (it is a parameter, not an artifact). Apply the question-relay rule. Gate: `STATUS: OK`.

## Step 4 — Deliverables

Dispatch `aegis:deliverables-kenshin` with the PRD and architecture paths. Gate: `STATUS: OK`. If its STATUS reports `flags=` > 0, read the Traceability Flags section — untraced deliverables and uncovered requirements go in the final report.

## Step 5 — Implementation specs (fan-out)

1. **Complexity gate first:** read `systems=`, `deliverables=`, and `est_size=` from kenshin's STATUS. When total deliverables ≤ 8 or `est_size=small`, dispatch **one** plan-lawliet for the whole feature — its prompt carries the deliverables path labeled "deliverable list — all systems, produce one consolidated spec in dependency order", the architecture path, and any existing documentation paths. The single spec feeds one aegis_simple_code run. The threshold is a heuristic, not a law: nine trivial deliverables still merit one spec.
2. Above the gate: from the deliverables document, list the systems. Dispatch one `aegis:plan-lawliet` per system — in waves per the Rules. Each prompt carries: the target system name, the deliverables path (labeled "deliverable list — scope to your system"), the architecture path, and any existing system documentation paths.
3. Gate each on `STATUS: OK`, then verify **one plan artifact per dispatch** exists in `.uzaak/plan-<uuid>-*.md` — parallel writers can collide on a same-second filename. Apply artifact-first recovery per the Rules; re-dispatch lawliet only for a system with no `Status: OK` artifact on disk.

## Step 6 — Report

Final message to the user: every artifact path (wish, PRD, architecture, deliverables, one plan per system — or the single consolidated plan), requirement/criteria/deliverable counts, evidence quality and open questions from the PRD, traceability flags if any, and the note that each plan artifact is a ready implementation spec for `code-kazuto` (e.g. via the aegis_simple_code pipeline).
