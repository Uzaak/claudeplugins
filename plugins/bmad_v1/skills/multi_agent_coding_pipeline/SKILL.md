Run the BMAD v6 agile pipeline. If no task is provided, ask first.

---

## Persistence Setup (run once, before anything else)

1. Derive a slug: lowercase, hyphens, first 4 words of the task (e.g. `rate-limiter-per-user`).
2. Compose the run directory: `bmad-artifacts/YYYY-MM-DD-{slug}/` relative to the current working directory.
3. **Resume check**: scan for existing `bmad-artifacts/*/` directories.
   - If any exist → list them and ask: *"Found prior run(s): [list]. Resume one, or start fresh?"*
   - If resuming → read all `.md` files present in the chosen run dir; for each artifact file that already exists, skip its generating agent and load the content from disk; announce: *"Resuming from: [first missing step]. Loaded: [list of loaded artifacts]."*
   - If starting fresh → proceed normally; the run directory is created implicitly on first write.

**Write rule**: after every agent produces output, immediately write its artifact to `{run-dir}/{filename}` using the Write tool, before prompting the user to continue.

---

## Phase 1 — Planning (once)

1. `agents/bmad-analyst.md` → task → **Brief** *(include language context + security constraints)*
   → write `product-brief.md`
2. `agents/bmad-pm.md` → Brief → **PRD** *(security ACs mandatory for I/O/auth epics)*
   → write `prd.md`
3. `agents/bmad-architect.md` → Brief + PRD → **Architecture** *(Security Architecture section required; OWASP table filled)*
   → write `architecture.md`
4. **Compress** → Epic Manifest. Discard prose — Manifest is the only planning artifact from here on.
   → write `epic-manifest.md`

**Epic Manifest format**:
| Epic | Task | Stories/ACs | Security ACs | Key Constraints |
|------|------|-------------|--------------|-----------------|
| Epic 1: {title} | T1.1: {imperative} | AC1, AC2 | SEC-1 | NFR-1 |

Show manifest → confirm: `Epics: [Epic 1: X (N tasks)...] Starting Epic 1 — confirm?`

---

## Phase 2 — Epic Loop (repeat per epic)

**A. Stories** — `agents/scrum-master.md`
- Input: Epic Manifest rows for current epic + Architecture
- Output: one `story-{slug}.md` per task (scoped architecture sections only; include Security Points)
- → write each `story-{task-slug}.md`

**B. Parallel Coding** — one subagent per story:
- Each receives: `agents/coder.md` + `story-{slug}.md`
- Orchestrator stores compact ref: `"T1.1: {file}.{ext}, {N} lines, implements {Interface}"`
- → write each `code-{task-slug}.md`

**C. QA** — `agents/qa.md`
- Input: ACs from Epic Manifest (including Security ACs) + full code
- Must include ≥1 security test per Security AC
- → write `tests-{task-slug}.md`

**D. Review + Stress** *(parallel)*:
- `agents/reviewer.md` → full code; apply language-specific checks → write `review-{task-slug}.md`
- `agents/stress.md` → full code + tests; include Security Under Stress → write `stress-{task-slug}.md`

**E. Verdict** — `agents/verdict.md`
- Input: Review score + Stress score + QA summary + AC checklist
- Security Gate section required; unmitigated CRITICAL security = automatic NOT READY
- → write `verdict-epic-{N}.md`
- → append a row to `scores.md`: `| Epic N | review | stress | QA | overall | status |`

**F. Checkpoint**

| Score | Security | Action |
|-------|----------|--------|
| ≥ 8.0 | No CRITICAL | Proceed to next epic or show final summary |
| ≥ 8.0 | CRITICAL security | Security fix required before shipping |
| < 8.0 | Any | Show issues; ask: *"Fix and re-run / skip / stop?"* |

On re-run: pass only the delta (CRITICAL/MAJOR issues + failing ACs).
Between epics: drop code + stories from context. Retain: Architecture + Manifest + all scores.

---

Use `references/output-format.md` headers. Show Pipeline Summary (with Security Gate + Coverage) after each Verdict.
Load agent files on demand — never pre-load all at once.
