---
name: writing-skills
description: Use when the user runs /writing-skills or asks to create or edit a skill (SKILL.md), especially when the skill should hold up under a reliability review such as skillspec doctor.
argument-hint: "[skill to create or edit, and where]"
---

# Writing Skills, Hardened

Author the skill through the standard writing-skills process, apply the hardening checklist while drafting, then verify with skillspec doctor when the CLI is installed.

## Rules — bind the whole task

- **Invoke `superpowers:writing-skills` via the Skill tool before authoring anything.** It owns the authoring process — naming, description discipline, testing, structure. This skill adds hardening and verification on top; it never replaces that process. If that skill is not available in the session, proceed with the checklist below and say so in the report.
- Keep the skill a single self-contained SKILL.md. Create supporting files only when the user asks for them; scratch work goes to the scratchpad or /tmp.
- Never create skillspec compile artifacts — no `skill.spec.yml`, no `deps.toml`, no trace/scenario surfaces — and never install the skillspec CLI. Doctor is a read-only reviewer here.
- Doctor verification is conditional on the CLI existing (`command -v skillspec`). Absent → skip Step 2 and state that verification was skipped.
- **Done-criteria for verification:** a doctor re-run after fixes shows no CRITICAL findings, 0 unlabeled fences, 0 late obligations (a terminal report-step instruction is acceptable), and discovery risk 0. Repeat fix → re-run until these hold.

## Hardening checklist — apply while drafting

Each item is a reliability-review failure class; write to pass them the first time.

1. **Frontmatter must parse as YAML.** Quote any value containing `[`, `]`, `|`, or `:` — an unquoted `argument-hint: [a] [b]` is malformed YAML and breaks skill discovery outright.
2. **Front-load binding obligations.** Every rule that governs the whole task goes in a "Rules" block immediately after the title. Instructions buried past the middle of the body get dropped under primacy bias. State each rule exactly once — no trailing "common mistakes" table repeating them.
3. **Recipes and templates before first use.** Any prompt recipe, template, or convention a step relies on must appear earlier in the document than that step.
4. **Label and classify every code fence.** Give each fence a language tag and say what it is: executable, a command example, or a non-executable template ("replace every placeholder").
5. **Declare the environment.** Name the binaries and services the steps assume (git, docker, a CLI) as a Rules line, so the dependency contract is explicit.
6. **Keep the activation body compact.** The whole SKILL.md loads at activation; aim under ~1,300 tokens by cutting content, not clarity — drop what doesn't change the reader's next action.

## Step 1 — Author

1. Invoke `superpowers:writing-skills` (per the Rules) and follow its process: trigger-only description starting "Use when…", one excellent example, testing discipline.
2. Draft the SKILL.md applying the hardening checklist as you write — not as a fix-up pass afterward.

## Step 2 — Verify with skillspec doctor (when installed)

Run doctor against the skill's directory and read every finding:

```sh
command -v skillspec && skillspec doctor <skill-directory>
```

Triage each finding — fix writing-level issues, skip compile-artifact asks:

| Finding class | Action |
|---|---|
| CRITICAL: frontmatter missing/malformed | Fix first, before every other finding |
| Late load-bearing instructions | Move into the Rules block, or ahead of first use |
| Unlabeled or ambiguous code fence | Label the language and classify the block |
| Implicit dependencies | Declare them in the Rules environment line (no `deps.toml`) |
| Most text loads at activation | Accepted for a deliberately single-file skill — tighten prose when the body is bloated |
| No `skill.spec.yml` / execution contract / trace surface / unproven runtime | Skip — compile artifacts, out of scope |

Re-run doctor after each fix round until the done-criteria in the Rules hold.

## Step 3 — Report

Final message: the skill's path, what was authored or changed, doctor status — verified (with the confirmation counts from Step 2) or skipped because the CLI is absent — each fix applied, and the residual findings accepted with a one-line reason each.
