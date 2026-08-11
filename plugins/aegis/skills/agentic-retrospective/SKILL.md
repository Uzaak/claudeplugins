---
name: agentic-retrospective
description: Use when the user asks for a retrospective, post-mortem, usage audit, or performance report on the agents dispatched during this conversation — per-agent mode (sequential/parallel), token cost, tool-call count, wall time, and produced document size, plus an assertiveness assessment with pros, cons, and improvement suggestions.
---

# Aegis: Agentic Retrospective

## Rules — bind the whole run

- Analyze the conversation this skill is invoked in, resolved fresh via `$CLAUDE_CODE_SESSION_ID` at run time — never reuse a session id or transcript path from a different chat or a previous run.
- Every number reported must come from the transcript's `toolUseResult` fields or a file actually read off disk — never estimate or infer a metric that isn't directly observable.
- Environment: `python3`, and read access to `~/.claude/projects/*/<session-id>.jsonl`.
- Mode is structural, not guessed: multiple `Agent` tool_use blocks inside one assistant message = parallel; one per message = sequential.
- Read each agent's full final report (and its artifact, when one exists) before judging assertiveness — a verdict from token or tool-call counts alone is not enough.
- Every agent gets one pros list and one cons list; every cons item pairs with a concrete improvement suggestion (a prompt phrasing to add, a missing input, a boundary it crossed).
- No agent dispatches found in the session → say so and stop; do not fabricate a report.

## Step 1 — Extract every agent dispatch

Run against the live session (executable):

```bash
python3 - <<'PY'
import json, glob, os
sid = os.environ["CLAUDE_CODE_SESSION_ID"]
paths = glob.glob(os.path.expanduser(f"~/.claude/projects/*/{sid}.jsonl"))
if not paths:
    raise SystemExit("no transcript found for session " + sid)
calls, order = {}, []
with open(paths[0]) as f:
    for line in f:
        d = json.loads(line)
        if d.get("type") == "assistant":
            content = d.get("message", {}).get("content", [])
            ids = [c["id"] for c in content if c.get("type") == "tool_use" and c.get("name") == "Agent"]
            for c in content:
                if c.get("type") == "tool_use" and c.get("name") == "Agent":
                    calls[c["id"]] = {
                        "agent": c["input"].get("subagent_type"),
                        "desc": c["input"].get("description"),
                        "mode": "parallel" if len(ids) > 1 else "sequential",
                    }
                    order.append(c["id"])
        elif d.get("type") == "user":
            content = d.get("message", {}).get("content", [])
            if not isinstance(content, list):
                continue
            for c in content:
                if c.get("type") == "tool_result" and c.get("tool_use_id") in calls:
                    tur = d.get("toolUseResult", {})
                    out = tur.get("usage", {}).get("output_tokens", 0)
                    total = tur.get("totalTokens", 0)
                    calls[c["tool_use_id"]].update(
                        duration_ms=tur.get("totalDurationMs"),
                        tool_calls=tur.get("totalToolUseCount"),
                        tokens_in=total - out,
                        tokens_out=out,
                        report=tur.get("content"),
                    )
if not order:
    raise SystemExit("no Agent dispatches found in this session")
for tid in order:
    print(json.dumps(calls[tid]))
PY
```

Prints one JSON object per dispatch, in call order: `agent`, `desc`, `mode`, `duration_ms`, `tool_calls`, `tokens_in`, `tokens_out`, `report` (content blocks — read the `text` fields for the agent's real final reply).

## Step 2 — Measure produced document size

For each dispatch's `report` text, find a `.md` path it names as its own artifact (e.g. `Artifact: /path/to/x.md`, or a `.uzaak/*.md` mention). File exists → count its lines. Otherwise → `n/a`; not every agent produces a document.

## Step 3 — Judge assertiveness per agent

Read the full `report` text (and the artifact, if one exists) and note concrete evidence:
- Did it complete the job in one clean pass, or backtrack/self-correct mid-report?
- Did it do work belonging to a different agent (e.g. a planning agent writing code, a review agent fixing instead of reporting)?
- Did its stated verdict/status match what the report body actually shows?
- Was its tool-call count proportionate to the task, or bloated by retries or confusion?

Turn these observations into the per-agent pros/cons lists (see Rules).

## Step 4 — Report

Present in chat; do not write to disk unless the user asks:

1. A table, one row per dispatch in call order: Agent | Mode | Tokens (in/out) | Doc lines | Tool calls | Wall time.
2. Per-agent pros/cons with the improvement suggestions from Step 3.
3. A short overall takeaway: which agent(s) underperformed, and the single highest-value fix for the next run.

Example row shape (non-executable, illustrative only):

```text
| Agent | Mode | Tokens (in/out) | Doc lines | Tool calls | Wall time |
|---|---|---|---|---|---|
| architecture-kayaba | sequential | 41,203 / 1,840 | 312 | 14 | 2m 18s |
| blue-team-alibaba | parallel | 38,910 / 1,205 | 190 | 22 | 3m 02s |
```

## Common Mistakes

- Treating `usage.input_tokens` as the input total — it's a small delta; real input cost is `totalTokens - output_tokens` (cache reads dominate almost every call).
- Grading assertiveness from a STATUS line alone — the line can claim `OK` while the report body shows backtracking or scope creep.
