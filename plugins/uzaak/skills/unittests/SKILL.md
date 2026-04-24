---
name: unittests
description: Generate tests to reach a target unit test coverage percentage. Detects stack/framework, measures baseline, fixes failing tests, and keeps filling coverage gaps until the target is reached.
argument-hint: [coverage%] [project-directory]
---

# uzaak: Unit Tests

Drive a project to a target unit test coverage percentage using a continuous measure-fix-generate loop.

## Step 0 — Parse arguments

Arguments may be provided in any order. Parse them as follows:

- If an argument is a number (integer or decimal), treat it as `target_pct`.
- If an argument is a string that looks like a directory path, treat it as the project directory.
- If no directory argument is given, use the current working directory.
- If no numeric argument is given, default `target_pct = 80`.

**Validate `target_pct`:**

| Condition | Action |
|---|---|
| Not a number (NaN, letters, symbols) | Print: `Expected a number between 1 and 100.` and stop. |
| Negative or zero | Print: `Expected a number between 1 and 100.` and stop. |
| Greater than 100 | Print: `Expected a number between 1 and 100.` and stop. |
| Greater than 90 | Set `best_effort = true`. Print: `Target >90% — will get as close as possible.` |
| 1–90 (inclusive) | Set `best_effort = false`. Use as-is. |

Print: `[<project>] target coverage: <target_pct>%`

## Step 1 — Detect stack and test framework

Check for these files (first match wins):

| File present | Stack |
|---|---|
| `go.mod` | go |
| `package.json` | node |
| `composer.json` | php |
| `requirements.txt` or `pyproject.toml` | python |
| `Gemfile` | ruby |
| (none) | unknown |

Then determine the test framework:

| Stack | Condition | Framework |
|---|---|---|
| go | always | go_test |
| node | `jest.config.*` exists | jest |
| node | no jest config | npm_test |
| php | always | phpunit |
| python | always | pytest |
| ruby | always | rspec |

Print: `[<project>] stack: <stack> | framework: <framework>`

## Step 2 — Measure baseline coverage

Run the coverage command for the detected framework:

| Framework | Command |
|---|---|
| go_test | `cd <dir> && go test -cover ./... 2>&1` |
| jest | `cd <dir> && npx jest --coverage --coverageReporters=text-summary 2>&1` |
| npm_test | `cd <dir> && npm test -- --coverage 2>&1` |
| phpunit | `cd <dir> && ./vendor/bin/phpunit --coverage-text 2>&1` |
| pytest | `cd <dir> && pytest --cov --cov-report=term-missing 2>&1` |
| rspec | `cd <dir> && bundle exec rspec --format progress 2>&1` |

Record:
- `baseline_exit`: 0 if tests passed, non-zero if they failed
- `baseline_pct`: integer coverage percentage parsed from output (see parsing rules below)
- Raw output for use in prompts

**Always print this immediately, before doing anything else:**
`[<project>] current coverage: <baseline_pct>%`

### Coverage parsing rules

**go_test** — grep for `\d+\.\d+(?=% of statements)`, average all matches, truncate to int. Default 0.

**jest / npm_test** — grep for the `Lines` row, extract the first decimal number, truncate to int. Default 0.

**pytest** — grep for the `TOTAL` line, extract the number before `%` on the last match, use as int. Default 0.

**rspec** — grep for `\d+\.\d+(?=% covered)`, take first match, truncate to int. Default 0.

**phpunit** — grep for `Lines:` line, extract the percentage, truncate to int. Default 0.

## Step 3 — Initial test generation (if baseline < target)

If the baseline is already >= `target_pct` and tests pass, skip directly to the summary.

Otherwise, do one initial generation pass before entering the loop:

- Use this prompt to guide the initial tests:

  > You are working on a `<stack>` project using `<framework>`.
  > Generate tests for the main application code to reach `<target_pct>`% coverage.
  > Focus on the most impactful files first (highest line count, core business logic).
  > Do not delete or alter any existing test cases.
  > You may add new test files or add new test cases to the end of existing test files.
  > Write the tests directly.

- Apply the tests.
- Then enter the Step 4 loop.

## Step 4 — Coverage loop (repeat until target reached)

Set `gap_iteration = 0`, `target_reached = false`, `last_pct = baseline_pct`.

Repeat until `target_reached == true`. **Do not stop or ask for confirmation between iterations — keep going autonomously.**

1. Increment `gap_iteration`.
2. Print: `[<project>] gap iteration <n> — measuring coverage...`
3. Run the coverage command again. Capture `current_exit`, `current_pct`, `current_output`.
4. Print: `[<project>] coverage: <current_pct>% | tests passing: yes/no`

### 4a — Fix failing tests (up to 2 attempts per iteration)

If `current_exit != 0`:

- Repeat up to 2 times while tests still fail:
  - Print: `[<project>] tests failing (fix attempt <n>/2) — fixing...`
  - Use the following prompt to guide your fixes:

    > You are working on a `<stack>` project using `<framework>`.
    > The test suite is currently failing. Fix the failing tests before writing any new ones.
    > Here is the test output:
    >
    > `<current_output>`
    >
    > Do not delete or alter passing tests. Fix the failures directly.

  - Apply fixes to the test files.
  - Re-run the coverage command and update `current_exit`, `current_pct`, `current_output`.

### 4b — Check if target reached

If `current_pct >= target_pct` AND `current_exit == 0`:
- Set `target_reached = true`
- Print: `[<project>] coverage target reached: <current_pct>%`
- Break out of loop.

**Best-effort mode** (`best_effort = true`): Also break if `current_exit == 0` AND coverage stopped improving (i.e. `current_pct == last_pct` after a full gap iteration with no new tests added). Print: `[<project>] best-effort ceiling reached: <current_pct>%`

### 4c — Generate gap-filling tests

If `current_pct < target_pct` (or tests still failing after fix attempts):

- Set `last_pct = current_pct`.
- Use the following prompt to guide writing additional tests:

  > You are working on a `<stack>` project using `<framework>`.
  > Current test coverage is `<current_pct>`%. The target is `<target_pct>`%.
  > Identify the files with the lowest coverage and write additional tests to close the gap.
  > Do not delete or alter any existing test cases.
  > You may add new test files or add new test cases to the end of existing test files.
  > Write the tests directly.

- Apply the new/extended test files.
- Continue to next gap iteration.

## Step 5 — Summary

**Always print a final summary, no matter how the loop ended:**

```
[<project>]
  target: <target_pct>%
  coverage: <baseline_pct>% → <current_pct>%
  target reached: yes / no
```

## Key rules

- **Dual-gate:** Coverage is only considered "reached" when BOTH `tests passing (exit=0)` AND `coverage >= target_pct` are true simultaneously.
- **Fix attempts don't count:** Fix-failing-test attempts (up to 2 per gap iteration) do not count as gap iterations.
- **Never delete existing tests:** Only append new test files or new test cases at the end of existing files.
- **Don't touch source code** to inflate coverage — only add or fix test code.
