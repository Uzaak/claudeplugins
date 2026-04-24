# BMad v6 Artifact Schemas

Schema and handoff contracts for each BMad v6 planning artifact.

---

## Artifact Chain

```
product-brief.md → PRD.md → architecture.md → story-{slug}.md
     (Mary)          (John)     (Winston)            (Bob)
```

Coder receives full `story-{slug}.md` + `architecture.md`. QA additionally receives the generated code.

---

## product-brief.md
Produced by: Mary | Consumed by: John

Required sections: Problem Statement · Target Users · Success Criteria · Scope (in/out) · Constraints & Dependencies (language/runtime) · Security Constraints (GDPR/PCI/HIPAA/SOC 2) · Key Risks & Unknowns (table: likelihood/impact) · Open Questions

---

## PRD.md
Produced by: John | Consumed by: Winston + all downstream agents

Required sections: Overview · Functional Requirements (FR-01…) · Non-Functional Requirements (table: ID, Category, Requirement, Target) · Security Acceptance Criteria (OWASP-aligned; ≥1 per epic with I/O or auth) · User Stories per epic · Out of Scope · Open Issues · Risks

Key rules: every FR ≥ 2 binary ACs · NFRs have measurable targets · ACs reference error/edge cases · security ACs mandatory for auth/input/external API epics

---

## architecture.md
Produced by: Winston | Consumed by: Bob + Amelia + Reviewer/Stress

Required sections: Overview · Tech Stack (table) · **Security Architecture** (threat model + OWASP Top 10 table + secrets strategy) · Component Design · Data Structures · Data Flow (show where auth checked + input validated) · API Contracts · ADRs · Edge Cases & Error Handling · NFR Notes · Implementation Checklist (TDD-friendly)

**Interface syntax by language** (use only the matching one):
| Language | Interface syntax |
|----------|-----------------|
| Java | `ReturnType methodName(ParamType p) throws DomainException;` in consumer-package interface |
| JS/TS | `methodName(p: ParamType): Promise<ReturnType>;` in `interface` block |
| PHP | `public function methodName(ParamType $p): ReturnType;` in `interface` |
| Go | `MethodName(ctx context.Context, p ParamType) (ReturnType, error)` in consumer-package interface |

**Type rules**: no `any`, no untyped `dict`, no raw `Object`. Java: `record`/final-field classes. PHP: typed properties (8+). Go: value types preferred.

---

## story-{slug}.md
Produced by: Bob | Consumed by: Amelia (PRIMARY INPUT)

Required sections: Context · Technical Context (components, interfaces in target language, types, NFR constraints, security mandates extracted from architecture) · Acceptance Criteria (PRD + technical + edge case + security ACs as checkboxes) · Implementation Notes (approach, security points, ordered steps, files, edge cases, do-nots) · Definition of Done (ACs · tests · coverage threshold · no sensitive data in logs/responses · lint clean · review ≥7 · stress ≥7)

---

## Artifact Passing Rules

1. Each downstream agent receives **full text** of all prior artifacts, not summaries.
2. Story file is the **primary context** for Coder — must be self-contained.
3. Missing required section → receiving agent must flag and request before proceeding.
4. Requirement change mid-pipeline → restart from affected artifact stage.
5. Security Architecture missing from architecture.md → Coder must request before implementing security-sensitive code.
