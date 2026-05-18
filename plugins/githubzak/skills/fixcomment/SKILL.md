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

**If no comment matches:**
Report "No inline comment found at `<FILENAME>:<LINENUMBER>`." and stop.

Note: if the user provided a file:line pointing to a general (non-inline) comment, report: "Only inline file comments can be targeted. Use `/checkcomments` to see which comments are inline."

**If multiple comments match** (rare, but possible when a file appears more than once in a PR):
List each match with its body and ask: "Multiple comments found at that location — which one should I fix?" Show them numbered and wait for the user to pick.

Store `COMMENT_ID` and `COMMENT_BODY`.

## Step 3 — Read code context

Read the file at `<FILENAME>` in the working tree. Focus on `<LINENUMBER>` and the 10 lines above and below it.

## Step 4 — Assess validity

Read `COMMENT_BODY` and the code context together. Use the following heuristics to decide how to proceed:

**Fix immediately (clearly valid):**
- DRY violation: same function called multiple times, result not saved and reused
- Logic error: code does something incorrect or misleading
- Security issue: any potential vulnerability
- Performance: a measurably wasteful pattern with a clear, simple fix

**Ask before fixing (questionable):**
- Redundant guard/null check: the variable was already checked and has not been reassigned between the two checks — adding a second check adds noise with no safety gain
- Style preference with no correctness impact: naming choices, formatting suggestions that don't affect behavior
- Increased complexity with no clear benefit

If questionable, say:
> "This fix may not be necessary because [specific reason based on the code and comment]. Do you want me to apply it anyway?"

Wait for the user's answer before proceeding.

## Step 5 — Fix the code

Edit the relevant file(s) in the working tree to address the comment. Do NOT stage or commit.

Report what was changed, referencing the specific lines modified.
