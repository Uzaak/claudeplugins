---
name: answercomment
description: Use when the user runs /answercomment — takes a file:line argument, finds that PR comment, and posts a reply on GitHub clearly attributed to Claude Code acting via the user's account.
argument-hint: <file:line>
---

# githubzak: Answer PR Comment

Post a reply to a specific inline PR comment on GitHub. The reply is clearly attributed to Claude Code so reviewers know it was not written directly by the PR author.

## Step 0 — Parse argument

The argument format is `<filename>:<linenumber>` — for example: `SuperNiceController.kt:183`.

If no argument was provided, ask: "Which comment should I answer? Provide it as `filename:linenumber` (e.g. `SuperNiceController.kt:183`)." Wait for the user's reply.

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

Find the comment where:
- `path` ends with `<FILENAME>`
- `line` equals `<LINENUMBER>`, OR `original_line` equals `<LINENUMBER>` when `line` is null

**If no comment matches:** report "No inline comment found at `<FILENAME>:<LINENUMBER>`" and stop.

**If the user targets a general comment:** report "Only inline file comments can be answered with `/answercomment`. Use the GitHub web UI to reply to general PR comments."

**If multiple comments match:** display each with index, line number, and body truncated to 80 characters:
```
(1) line 183 — "You're calling the same function twice, save the result..."
(2) line 183 — "This variable name is confusing, consider renaming to..."
```
Ask: "Multiple comments found at that location — which one should I answer? Enter the number." Wait for the user's reply.

Store `COMMENT_ID` and `COMMENT_BODY`.

Note: if `line` is null, the comment is outdated (posted on code that has since changed). Warn: "This comment is outdated — it was posted on code that has since changed. Do you still want to post a reply?" and wait for the user's answer.

## Step 3 — Read code context

The comment's `path` field contains the full relative path from the repo root. Use this path to read the file in the working tree, focusing on `<LINENUMBER>` and 10 lines either side. If the file does not exist, continue — the reply can still be posted based on the comment body alone.

## Step 4 — Get GitHub username

```bash
GH_USERNAME=$(gh api user --jq '.login')
```

## Step 5 — Compose reply

Write a reply that:
- Opens with exactly: `**[Claude Code, via @<GH_USERNAME>]**`
- Then a blank line
- Then directly addresses the comment: what was done, why a decision was made, or what clarification is needed
- Is concise and professional — no filler phrases

Example structure:
```
**[Claude Code, via @uzaak]**

The duplicate call has been refactored — the result is now stored in `result` and reused on line 185. Let me know if you'd like any further changes.
```

Before posting, show the user the composed reply and ask: "Ready to post this reply? (yes/no)" Wait for confirmation. If they say no or want changes, revise and re-show.

## Step 6 — Post the reply

```bash
gh api --method POST "repos/<OWNER>/<REPO>/pulls/comments/<COMMENT_ID>/replies" \
  -f body="<full reply text>"
```

Report the `html_url` from the response so the user can verify the posted reply.
