---
name: fixcomment
description: Use when the user runs /fixcomment — takes a file:line argument, finds that PR comment, assesses whether it is valid, and fixes the code if appropriate. Asks the user before acting on questionable comments.
argument-hint: <file:line>
---

# githubzak: Fix PR Comment

Act on a specific PR comment identified by its file and line number. Edits the working tree only — does not stage or commit.

## Step 0 — Parse argument

The argument format is `<filename>:<linenumber>` — for example: `SuperNiceController.kt:183`.

If no argument was provided, ask: "Which comment should I fix? Provide it as `filename:linenumber` (e.g. `SuperNiceController.kt:183`)." Wait for the user's reply.

Parse `FILENAME` (the part before the last `:`) and `LINENUMBER` (the integer after the last `:`).

## Step 1 — Verify prerequisites and find PR

Run in sequence:
```bash
gh auth status
BRANCH=$(git branch --show-current)
PR_NUMBER=$(gh pr list --head <BRANCH> --state open --json number --jq '.[0].number')
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
```

Stop with a clear message if any step fails (auth error, detached HEAD, no open PR).

## Step 2 — Find the comment

Fetch all inline review comments:
```bash
gh api "repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments?per_page=100"
```

Find the comment where both conditions are true:
- `path` ends with `<FILENAME>` (to handle files in subdirectories, e.g. `com/example/SuperNiceController.kt` matches `SuperNiceController.kt`)
- `line` equals `<LINENUMBER>`, OR (if `line` is null) `original_line` equals `<LINENUMBER>`

Note: if `line` is null, the comment is "outdated" (posted on code that has since changed). `original_line` refers to the old line number, which may no longer match the current file. Warn the user: "This comment is outdated — it was posted on code that has since changed. The line reference may be inaccurate. Do you still want to proceed?" and wait for their answer.

**If no comment matches:**
Report "No inline comment found at `<FILENAME>:<LINENUMBER>`." and stop.

Note: if the user provided a file:line pointing to a general (non-inline) comment, report: "Only inline file comments can be targeted. Use `/checkcomments` to see which comments are inline."

**If multiple comments match** (rare, but possible when a file appears more than once in a PR):
Display each match with its index, the line number, and the body truncated to 80 characters. Example:
```
(1) line 183 — "You're calling the same function twice, save the result..."
(2) line 183 — "This variable name is confusing, consider renaming to..."
```
Ask: "Multiple comments found at that location — which one should I fix? Enter the number."

Store `COMMENT_ID` and `COMMENT_BODY`.

## Step 3 — Read code context

The comment's `path` field contains the full relative path from the repo root (e.g., `src/main/kotlin/SuperNiceController.kt`). Use this full path to read the file — do NOT use just the `FILENAME` portion. If the file does not exist at that path, report: "File `<path>` not found in the working tree. It may have been deleted or moved." and stop.

Focus on `<LINENUMBER>` and the 10 lines above and below it.

## Step 4 — Assess validity

Read `COMMENT_BODY` and the code context together. Use the following heuristics to decide how to proceed:

**Fix immediately (clearly valid):**
- DRY violation: same function called multiple times, result not saved and reused
- Logic error: code does something incorrect or misleading
- Security issue: use of a known-vulnerable API, SQL/command injection pattern, missing input escaping in an obvious context, hardcoded secret, or unsafe deserialization. Do not classify speculative threats or architecture concerns as security issues.
- Performance: a well-known inefficiency with a straightforward fix — e.g., an O(n²) loop where O(n) is possible, rebuilding a collection on every call instead of caching it, or repeated I/O that could be batched. Do not classify subjective micro-optimisations as performance issues.

**Ask before fixing (questionable):**
- Redundant guard/null check: the variable was already checked and has not been reassigned between the two checks — adding a second check adds noise with no safety gain
- Style preference with no correctness impact: naming choices, formatting suggestions that don't affect behavior
- Increased complexity with no clear benefit

If questionable, say:
> "This fix may not be necessary because [specific reason based on the code and comment]. Do you want me to apply it anyway?"

Proceed if the user responds with an affirmative (e.g., "yes", "go ahead", "do it", "fix it"). If they decline (e.g., "no", "skip", "leave it") or are unclear, ask for clarification. Do not proceed on ambiguous input.

Wait for the user's answer before proceeding.

## Step 5 — Fix the code

Edit the relevant file(s) in the working tree to address the comment. Do NOT stage or commit.

Report what was changed, referencing the specific lines modified.
