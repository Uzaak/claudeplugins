# Multi-Agent Development Pipeline

A set of 16 deployable [Claude Code](https://claude.ai/code) agents that take a feature from raw idea to approved delivery. Installing the **aegis** plugin makes all agents in [`agents/`](agents/) available automatically — no manual copying required.

All agents share a common interop contract: inputs are accepted as file paths or inline content, a run UUID is threaded through the whole pipeline, and every agent writes a self-contained report artifact to a git-ignored `.uzaak/` directory, returning a machine-readable `STATUS:` line to the orchestrator. Agents that boot the application do so under their own isolated Docker Compose project and port, so parallel runs never collide.

## Quick Reference

| Agent | Input | Work done | Output |
|---|---|---|---|
| `prd-chihiro` | Raw notes, transcripts, feature requests | Structures and scopes into a 7-section PRD | PRD document |
| `architecture-kayaba` | PRD + list of systems/languages | Designs 8-section technical architecture | Architecture document |
| `deliverables-kenshin` | PRD + architecture doc | Breaks feature into ordered, traceable deliverables per system | Delivery plan |
| `plan-lawliet` | One system's deliverables + architecture doc | Writes exact implementation spec per deliverable | Implementation spec |
| `code-kazuto` | Implementation spec | Implements every deliverable via strict TDD | Working committed code + report |
| `unit-test-deedee` | Codebase | Writes fully mocked unit tests to ≥85% line coverage | Committed tests + coverage report |
| `telemetry-alpha` | Codebase | Adds metrics/events via an isolated telemetry module | Committed instrumentation + report |
| `integration-test-mayuri` | Codebase | Writes and runs E2E Cypress tests | Committed `/integration` suite + report |
| `load-test-toguro` | Codebase | Writes K6 load scripts, validated by a smoke run | Committed `/stress` scripts + report |
| `preflight-slippy` | Codebase | Verifies build, launch, test suites, and CLAUDE.md | Readiness report |
| `technical-review-lucca` | Codebase + architecture doc | Audits architecture compliance | Compliance report |
| `product-review-bulma` | Codebase + PRD | Audits PRD compliance | Compliance report |
| `blue-team-alibaba` | Codebase + architecture doc | Static security review (OWASP Top 10 +) | Security findings report |
| `red-team-medjed` | Codebase (app running) | Actively attacks the live app for real breaches | Breach + clearance report |
| `approve-samuel` | All review reports | Judges every finding and rules on delivery | Verdict document |
| `debugger-itachi` | A bug report or symptom | Traces the failure to its root cause; fixes nothing | Diagnosis report |

## Planning agents (read-only)

### `prd-chihiro`
- **Input:** raw, unstructured information — documents, meeting transcripts, Slack conversations, feature requests, freeform notes.
- **Work done:** parses the input, surfaces contradictions and assumptions (asking up to two rounds of clarifying questions, or none in silent mode), and produces a complete 7-section PRD with goals, non-goals, "if/then" requirements with edge cases, and Gherkin acceptance criteria.
- **Output:** a self-contained PRD document, with every assumption and open question documented and evidence quality flagged.

### `architecture-kayaba`
- **Input:** the PRD plus the list of involved systems and their programming languages.
- **Work done:** designs the full technical architecture across 8 sections — system responsibilities and boundaries, tech stack (justified), synchronous/asynchronous contracts, data models, integration points, and every architectural decision with its reasoning. May ask up to two rounds of questions.
- **Output:** a self-contained architecture document that downstream agents treat as the technical source of truth.

### `deliverables-kenshin`
- **Input:** the PRD and the architecture document.
- **Work done:** breaks the feature into single-testable-unit deliverables, grouped by system and sorted by implementation dependency, then verifies traceability in both directions — every deliverable maps to a PRD requirement and every requirement is covered.
- **Output:** an ordered delivery plan with traceability flags for anything untraced or uncovered.

### `plan-lawliet`
- **Input:** a single system's deliverable list, the architecture document, and any existing system documentation.
- **Work done:** expands each deliverable into an unambiguous implementation spec — file paths, behavior and validation rules, dependencies, method signatures, and data structures — detailed enough to implement without asking questions, informed by relevant tech-stack skills.
- **Output:** a complete implementation spec for the system, ready to hand to the code agent.

## Building agents (mutate the repo)

### `code-kazuto`
- **Input:** the implementation spec and any existing system documentation.
- **Work done:** implements every deliverable using strict RED-GREEN-REFACTOR TDD, following SOLID and REST/MVVM standards, then verifies the app builds and launches under its own isolated Compose project. Commits atomically with co-author trailers.
- **Output:** working, tested, committed code plus a report of every file changed, every commit, and any spec deviations.

### `unit-test-deedee`
- **Input:** the application codebase and any existing system documentation.
- **Work done:** writes fully isolated unit tests (all external dependencies mocked), covering the happy path, failure scenarios, and adversarial inputs, and iterates until line coverage reaches at least 85%.
- **Output:** committed test files plus a report of coverage achieved and notable scenarios covered.

### `telemetry-alpha`
- **Input:** the application codebase and any existing system documentation.
- **Work done:** detects the telemetry library in use (defaulting to Prometheus for backends, Google Analytics for frontends) and routes all instrumentation through a centralized, isolated module so every metric launch is exactly one line of application code, with sensitive data masked before emission.
- **Output:** committed instrumentation plus a report listing every metric/event, its trigger, and its emission point.

### `integration-test-mayuri`
- **Input:** the application codebase and any existing system documentation.
- **Work done:** creates the `/integration` Cypress suite if absent, brings the app up in isolation, writes end-to-end tests covering all defined behavior — including at least one test per telemetry metric — and runs the full suite against localhost, verifying every test cleans up after itself.
- **Output:** a committed Cypress suite plus a report of every scenario, environments targeted, and the local run outcome.

### `load-test-toguro`
- **Input:** the application codebase and any existing system documentation.
- **Work done:** creates the `/stress` directory if absent and writes K6 load scripts following a configurable ramp-up + sustain pattern with multi-environment targeting, validating each with a 1-minute single-user smoke run before committing.
- **Output:** committed K6 scripts plus a report of the configuration and smoke run outcome.

## Verification and review agents (read-only)

### `preflight-slippy`
- **Input:** the working codebase and any existing system documentation.
- **Work done:** verifies the application is delivery-ready — builds it, launches it in isolation, runs the Cypress and K6 suites if present, and checks that CLAUDE.md documents how to build, run, and test. Read-only except a narrow exception to fix a failing build or app start.
- **Output:** an operational readiness report covering every step's status.

### `technical-review-lucca`
- **Input:** the codebase, the architecture document, and any existing system documentation.
- **Work done:** audits the implementation against the architecture — verifying each system honors its responsibilities and that no contract, boundary, data model, or recorded decision has been violated.
- **Output:** a compliance report with a Pass / Drift / Violation verdict per architectural rule and the location of every violation.

### `product-review-bulma`
- **Input:** the codebase, the PRD, and any existing system documentation.
- **Work done:** audits the implementation against the PRD as the authoritative source of truth, checking every functional requirement and acceptance criterion for gaps, deviations, or missing behavior.
- **Output:** a compliance report with a Met / Partially met / Unmet verdict per requirement and criterion.

### `blue-team-alibaba`
- **Input:** the codebase, the architecture document, and any existing system documentation.
- **Work done:** performs a static security review across the full OWASP Top 10 plus additional security dimensions, recording severity, location, exploitation path, and correct-implementation guidance for each finding.
- **Output:** a security findings report where every checked item is either a finding or explicitly cleared.

### `red-team-medjed`
- **Input:** the codebase, with the application running under its own isolated instance.
- **Work done:** actively attacks the live application — enumerating every endpoint, input, header, cookie, and parameter — and reports only confirmed breaches, each with the exact payload, response, impact, and a self-contained reproduction script. Fixes nothing.
- **Output:** a breach report plus an explicit clearance list of every surface tested safe.

## Verdict

### `approve-samuel`
- **Input:** any combination of the product, technical, blue-team, and red-team review reports.
- **Work done:** exercises judgment over every finding — assessing severity, user impact, and materiality — and classifies each as blocking or technical debt. An absent review is never treated as a pass; uncovered dimensions are called out explicitly.
- **Output:** a single reasoned verdict — Approved, Approved with technical debt, or Rejected — describing every open item so the responsible agent knows what to fix.

## On-demand

### `debugger-itachi`
- **Input:** a reported error or misbehavior (e.g. an endpoint returning 500, a wrong calculation) and any existing system documentation.
- **Work done:** traces the execution path, forms hypotheses, adds temporary instrumentation to reproduce the issue reliably, confirms the root cause, then removes every trace of its instrumentation. Finds only — never fixes.
- **Output:** a diagnosis report with the exact trigger conditions, root cause location (file, class, line), and actual-vs-expected behavior.
