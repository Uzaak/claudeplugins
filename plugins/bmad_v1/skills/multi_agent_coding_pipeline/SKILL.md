Run the BMAD v6 agile pipeline. If no task is provided, ask first.

---

## Phase 1 — Planning (once)

1. `agents/bmad-analyst.md` → task → **Brief** *(include language context + security constraints)*
2. `agents/bmad-pm.md` → Brief → **PRD** *(security ACs mandatory for I/O/auth epics)*
3. `agents/bmad-architect.md` → Brief + PRD → **Architecture** *(Security Architecture section required; OWASP table filled)*
4. **Compress** → Epic Manifest. Discard prose — Manifest is the only planning artifact from here on.

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

**B. Parallel Coding** — one subagent per story:
- Each receives: `agents/coder.md` + `story-{slug}.md`
- Orchestrator stores compact ref: `"T1.1: {file}.{ext}, {N} lines, implements {Interface}"`

**C. QA** — `agents/qa.md`
- Input: ACs from Epic Manifest (including Security ACs) + full code
- Must include ≥1 security test per Security AC

**D. Review + Stress** *(parallel)*:
- `agents/reviewer.md` → full code; apply language-specific checks
- `agents/stress.md` → full code + tests; include Security Under Stress

**E. Verdict** — `agents/verdict.md`
- Input: Review score + Stress score + QA summary + AC checklist
- Security Gate section required; unmitigated CRITICAL security = automatic NOT READY

**F. Checkpoint**

| Score | Security | Action |
|-------|----------|--------|
| ≥ 8.0 | No CRITICAL | Proceed to next epic or show final summary |
| ≥ 8.0 | CRITICAL security | Security fix required before shipping |
| < 8.0 | Any | Show issues; ask: *"Fix and re-run / skip / stop?"* |

On re-run: pass only the delta (CRITICAL/MAJOR issues + failing ACs).
Between epics: drop code + stories. Retain: Architecture + Manifest + all scores.

---

Use `references/output-format.md` headers. Show Pipeline Summary (with Security Gate + Coverage) after each Verdict.
Load agent files on demand — never pre-load all at once.
