---
name: checkcomments
description: Use when the user runs /checkcomments — reads the current branch, finds the open PR, and lists all comments with file name and line number. Read-only, no changes made.
---

# githubzak: Check PR Comments

List all open comments on the current branch's PR. No actions taken, no files modified.

## Step 1 — Verify prerequisites

Check that `gh` is available and authenticated:

```bash
gh auth status
```

If this fails, report the error and stop. Do not proceed without a working `gh` session.

## Step 2 — Get current branch

```bash
git branch --show-current
```

If the output is empty (detached HEAD), report "Not on a named branch — cannot look up a PR" and stop.

Store the result as `BRANCH`.

## Step 3 — Find open PR

```bash
gh pr list --head <BRANCH> --state open --json number,url --jq '.[0]'
```

If the result is empty or null, report "No open PR found for branch `<BRANCH>`" and stop.

Store `PR_NUMBER` and `PR_URL` from the result.

## Step 4 — Get owner and repo

```bash
gh repo view --json owner,name --jq '{owner: .owner.login, repo: .name}'
```

Store `OWNER` and `REPO`.

## Step 5 — Fetch inline review comments

```bash
gh api "repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments"
```

Each item has:
- `path` — file path relative to repo root
- `line` — current line number (may be null for outdated comments; fall back to `original_line`)
- `body` — comment text
- `id` — comment ID (needed by fixcomment and answercomment)

## Step 6 — Fetch general PR comments

```bash
gh api "repos/<OWNER>/<REPO>/issues/<PR_NUMBER>/comments"
```

Each item has:
- `body` — comment text
- `id` — comment ID
- No `path` or `line` — these are top-level PR comments, not tied to a file

## Step 7 — Display results

Print the PR URL first, then the comment list.

Group inline comments by file, sorted by line number. Truncate comment bodies to 80 characters with `...` if longer.

Output format:

```
PR: <PR_URL>

### Inline comments

SuperNiceController.kt:183  — "You're calling the same function twice..."
SuperNiceController.kt:210  — "This method is too long, consider extracting..."
AuthService.kt:44           — "Missing null check here"

### General comments

[General] — "Overall this PR looks good but the error handling needs work"
```

If there are no inline comments, print "No inline comments." under that section.
If there are no general comments, print "No general comments." under that section.
If there are no comments at all, print "No comments found on PR #<PR_NUMBER>."
