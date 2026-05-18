# githubzak Plugin — Design Spec

**Date:** 2026-05-18
**Status:** Approved

## Overview

`githubzak` is a new Claude Code plugin consolidating GitHub PR workflow skills. It replaces PR-related skills currently scattered in `uzaak` and adds three new skills for reviewing, acting on, and responding to PR comments.

## Plugin Structure

```
plugins/githubzak/
  .claude-plugin/plugin.json
  skills/
    checkcomments/SKILL.md
    fixcomment/SKILL.md
    answercomment/SKILL.md
    cplb/SKILL.md              ← migrated from uzaak
```

**Changes to existing files:**
- `plugins/uzaak/skills/cplb/` — deleted (moved to githubzak)
- `plugins/uzaak/.claude-plugin/plugin.json` — remove cplb skill reference if listed
- `.claude-plugin/marketplace.json` — add `githubzak` entry

## Prerequisite

All skills assume `gh` CLI is installed and authenticated. If a `gh` command fails with an auth error, skills must surface the error clearly and stop.

## Skills

### `/checkcomments`

**Purpose:** Read-only. Lists all open PR comments for the current branch.

**Steps:**
1. Get current branch: `git branch --show-current`
2. Find open PR: `gh pr list --head <branch> --state open --json number,url,headRepository`
3. If no open PR found: report clearly and stop.
4. Fetch inline review comments: `gh api repos/{owner}/{repo}/pulls/<number>/comments`
5. Fetch issue-level (general) PR comments: `gh api repos/{owner}/{repo}/issues/<number>/comments`
6. Print a flat list grouped by file, sorted by line number:

```
SuperNiceController.kt:183  — "You're calling the same function twice..."
SuperNiceController.kt:210  — "This method is too long..."
AuthService.kt:44           — "Missing null check here"
[General] — "Overall this PR looks good but the error handling needs work"
```

General (non-inline) comments are prefixed with `[General]` and have no file:line.

**No action is taken. No files are modified.**

---

### `/fixcomment <file:line>`

**Purpose:** Understand a specific PR comment, judge its validity, and fix the code if appropriate.

**Argument format:** `filename:linenumber` — e.g. `SuperNiceController.kt:183`

**Steps:**
1. If no argument provided: ask "Which comment should I fix? Provide it as `filename:linenumber`."
2. Get current branch and open PR (same as checkcomments).
3. Fetch inline review comments and find the one where `path` ends with `<filename>` (to handle subdirectories) and `line` or `original_line` equals `<linenumber>`.
4. If no matching comment found: report clearly and stop.
5. Read the comment body.
6. **Validity assessment:**
   - Read the relevant code at the file and surrounding lines for context.
   - Reason about whether the comment is correct and actionable:
     - **Clearly valid** (e.g. "you're calling the same function twice, save and reuse the result"): proceed to fix.
     - **Questionable** (e.g. "validate this isn't null even though it was checked two lines ago with no mutations in between"): present your counterpoints and ask the user: "This fix may not be necessary because [reason]. Do you want me to apply it anyway?"
7. If fixing: edit the relevant file(s) in the working tree. Do not stage or commit.
8. Report what was changed (or why nothing was changed).

**Validity heuristics:**
- Redundant checks with no intervening mutations → questionable
- Style preferences with no correctness impact → questionable
- Performance improvements, logic errors, DRY violations → valid
- Security issues → always valid, fix immediately

---

### `/answercomment <file:line>`

**Purpose:** Post a reply to a specific PR comment on GitHub, authored as Claude Code acting via the user's account.

**Argument format:** `filename:linenumber` — e.g. `SuperNiceController.kt:183`

**Steps:**
1. If no argument provided: ask "Which comment should I answer? Provide it as `filename:linenumber`."
2. Get current branch and open PR.
3. Fetch inline review comments and find the matching comment (same lookup as fixcomment: path ends with `<filename>`, line equals `<linenumber>`).
4. If no matching comment found: report clearly and stop.
5. Get the authenticated GitHub username: `gh api user --jq '.login'`
6. Read the comment body and the surrounding code context (a few lines either side of the target line).
7. Compose a reply that:
   - Starts with: `**[Claude Code, via @<github-username>]**`
   - Directly addresses the comment (explains what was done, why a change was or wasn't made, or asks a clarifying question)
   - Is concise and professional
8. Post the reply: `gh api repos/{owner}/{repo}/pulls/comments/<comment-id>/replies -f body="<reply>"`
9. Report the URL of the posted reply.

---

### `/cplb` (migrated from uzaak)

No changes to behavior. Identical `SKILL.md` content. Migrated to `githubzak` because it is GitHub PR workflow — consistent with this plugin's scope.

---

## Corner Cases

| Situation | Action |
|-----------|--------|
| Not on a branch / detached HEAD | Report and stop |
| No open PR for current branch | Report and stop |
| `file:line` matches zero comments | Report "no comment found at `<file:line>`" and stop |
| `file:line` matches multiple comments | List them all with their bodies and ask the user which to act on |
| `gh` not installed or not authenticated | Report the exact error; do not proceed |
| PR has no comments at all | `/checkcomments` reports "No comments found on this PR" |

## Intentional Gaps

- General (non-inline) PR comments shown by `/checkcomments` cannot be targeted by `/fixcomment` or `/answercomment` — those skills only resolve inline file:line comments. If the user tries, report that only inline comments are supported.

## Out of Scope

- Resolving/dismissing comments (not requested)
- Handling draft PRs differently (treat same as open)
- Multi-PR support per branch (use the first open PR found)
- Fetching comments from closed PRs
