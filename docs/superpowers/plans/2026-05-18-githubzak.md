# githubzak Plugin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a new `githubzak` Claude Code plugin with three GitHub PR comment skills (`checkcomments`, `fixcomment`, `answercomment`) and migrate `cplb` from the `uzaak` plugin.

**Architecture:** Four markdown skill files in `plugins/githubzak/skills/`, each a self-contained instruction set for Claude. Skills use the `gh` CLI for all GitHub API interactions. No shared state between skills — each re-fetches what it needs from GitHub.

**Tech Stack:** `gh` CLI (GitHub), `git` CLI, Claude Code plugin system (markdown-based skill files).

---

## File Map

| Action | Path |
|--------|------|
| Create | `plugins/githubzak/.claude-plugin/plugin.json` |
| Create | `plugins/githubzak/skills/cplb/SKILL.md` |
| Create | `plugins/githubzak/skills/checkcomments/SKILL.md` |
| Create | `plugins/githubzak/skills/fixcomment/SKILL.md` |
| Create | `plugins/githubzak/skills/answercomment/SKILL.md` |
| Delete | `plugins/uzaak/skills/cplb/SKILL.md` |
| Modify | `.claude-plugin/marketplace.json` |

---

## Task 1: Create the githubzak plugin scaffold

**Files:**
- Create: `plugins/githubzak/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create the plugin directory and plugin.json**

Create the file `plugins/githubzak/.claude-plugin/plugin.json` with this exact content:

```json
{
  "name": "githubzak",
  "description": "githubzak plugin — GitHub PR workflow skills: check, fix, and answer PR comments",
  "author": {
    "name": "Tiago Furlanetto"
  }
}
```

- [ ] **Step 2: Register the plugin in marketplace.json**

The current `.claude-plugin/marketplace.json` looks like:

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "uzaak",
  "description": "Uzaak local plugin marketplace",
  "owner": {
    "name": "Tiago Furlanetto"
  },
  "plugins": [
    {
      "name": "uzaak",
      "description": "Custom slash commands for local dev workflows",
      "source": "./plugins/uzaak"
    },
    {
      "name": "bmad_v1",
      "description": "BMAD v1 — 9-agent multi-agent coding pipeline (planning → implementation → QA → verdict)",
      "source": "./plugins/bmad_v1"
    }
  ]
}
```

Add a `githubzak` entry to the `plugins` array so the final file reads:

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "uzaak",
  "description": "Uzaak local plugin marketplace",
  "owner": {
    "name": "Tiago Furlanetto"
  },
  "plugins": [
    {
      "name": "uzaak",
      "description": "Custom slash commands for local dev workflows",
      "source": "./plugins/uzaak"
    },
    {
      "name": "bmad_v1",
      "description": "BMAD v1 — 9-agent multi-agent coding pipeline (planning → implementation → QA → verdict)",
      "source": "./plugins/bmad_v1"
    },
    {
      "name": "githubzak",
      "description": "GitHub PR workflow skills — check, fix, and answer PR comments",
      "source": "./plugins/githubzak"
    }
  ]
}
```

- [ ] **Step 3: Verify structure**

Run:
```bash
find plugins/githubzak -type f
```

Expected output:
```
plugins/githubzak/.claude-plugin/plugin.json
```

- [ ] **Step 4: Commit**

```bash
git add plugins/githubzak/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat(githubzak): scaffold new plugin with marketplace registration"
```

---

## Task 2: Migrate cplb from uzaak to githubzak

**Files:**
- Create: `plugins/githubzak/skills/cplb/SKILL.md`
- Delete: `plugins/uzaak/skills/cplb/SKILL.md`

- [ ] **Step 1: Create the skills directory and copy cplb**

Create `plugins/githubzak/skills/cplb/SKILL.md` with this exact content (identical to the uzaak version):

```markdown
---
name: cplb
description: Use when the user runs /cplb with a branch name argument — creates or switches to the branch, commits all current changes with a generated message, pushes to remote, and opens a PR to main or master.
---

# cplb — Commit, Push, Leave Building

Invoked as `/cplb <branch-name>`. Execute these steps in order.

## Steps

**1. Resolve branch**

Check current branch and whether target branch exists:
- Already on `<branch-name>` → proceed
- Branch exists, not current → `git checkout <branch-name>`
- Branch doesn't exist → `git checkout -b <branch-name>`

Never switch branches if there are uncommitted changes on a *different* branch — warn the user and stop.

**2. Stage all changes**

```bash
git add -A
```

**3. Write commit message**

Read the full diff:
```bash
git diff --cached
```

Write a meaningful commit message:
- Subject: imperative mood, ≤72 chars, describes WHAT changed
- Body (optional): WHY if not obvious from the diff
- Never use generic messages like "WIP", "update", or "fix stuff"

**4. Commit**

```bash
git commit -m "$(cat <<'EOF'
<subject line>

<optional body>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

**5. Push**

```bash
git push -u origin <branch-name>
```

**6. Determine default branch**

```bash
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
```

Fall back to trying `main`, then `master` if the above fails.

**7. Open PR**

```bash
gh pr create --base <default-branch> --head <branch-name> \
  --title "<commit subject>" \
  --body "$(cat <<'EOF'
## Summary
<brief bullet points of what changed>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

If a PR already exists for this branch, report its URL instead of creating a new one.

## Corner Cases

| Situation | Action |
|-----------|--------|
| Already on target branch | Skip branch creation, proceed with commit |
| Branch exists, not current | `git checkout <branch-name>` |
| Branch doesn't exist | `git checkout -b <branch-name>` |
| Working tree is clean (nothing to commit) | Skip commit + push; still attempt to open or report PR |
| No remote `origin` | Report clearly, stop after commit |
| `gh` not installed or not authenticated | Report the exact reason; show the manual `gh pr create` command |
| PR creation fails for any reason | Show exact error from `gh`; do not silently swallow it |
```

- [ ] **Step 2: Delete the old cplb from uzaak**

```bash
rm plugins/uzaak/skills/cplb/SKILL.md
rmdir plugins/uzaak/skills/cplb
```

- [ ] **Step 3: Verify**

Run:
```bash
find plugins/uzaak/skills -type f
find plugins/githubzak/skills -type f
```

Expected — `cplb` must not appear under uzaak, and must appear under githubzak:
```
plugins/uzaak/skills/analyse_architecture/SKILL.md
plugins/uzaak/skills/analyse_endpoints/SKILL.md
plugins/uzaak/skills/dockercomposefix/SKILL.md
plugins/uzaak/skills/doctor/SKILL.md
plugins/uzaak/skills/unittests/SKILL.md
plugins/githubzak/skills/cplb/SKILL.md
```

- [ ] **Step 4: Commit**

```bash
git add plugins/githubzak/skills/cplb/SKILL.md
git rm plugins/uzaak/skills/cplb/SKILL.md
git commit -m "feat(githubzak): migrate cplb skill from uzaak"
```

---

## Task 3: Implement the checkcomments skill

**Files:**
- Create: `plugins/githubzak/skills/checkcomments/SKILL.md`

- [ ] **Step 1: Create the skill file**

Create `plugins/githubzak/skills/checkcomments/SKILL.md` with this exact content:

```markdown
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
```

- [ ] **Step 2: Verify the file exists and has correct frontmatter**

Run:
```bash
head -5 plugins/githubzak/skills/checkcomments/SKILL.md
```

Expected output must start with:
```
---
name: checkcomments
description: Use when the user runs /checkcomments
```

- [ ] **Step 3: Commit**

```bash
git add plugins/githubzak/skills/checkcomments/SKILL.md
git commit -m "feat(githubzak): add checkcomments skill"
```

---

## Task 4: Implement the fixcomment skill

**Files:**
- Create: `plugins/githubzak/skills/fixcomment/SKILL.md`

- [ ] **Step 1: Create the skill file**

Create `plugins/githubzak/skills/fixcomment/SKILL.md` with this exact content:

```markdown
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
git branch --show-current
gh pr list --head <BRANCH> --state open --json number,url --jq '.[0]'
gh repo view --json owner,name --jq '{owner: .owner.login, repo: .name}'
```

Stop with a clear message if any step fails (auth error, detached HEAD, no open PR).

Store `BRANCH`, `PR_NUMBER`, `OWNER`, `REPO`.

## Step 2 — Find the comment

Fetch all inline review comments:
```bash
gh api "repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments"
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
```

- [ ] **Step 2: Verify**

```bash
head -5 plugins/githubzak/skills/fixcomment/SKILL.md
```

Expected:
```
---
name: fixcomment
description: Use when the user runs /fixcomment
```

- [ ] **Step 3: Commit**

```bash
git add plugins/githubzak/skills/fixcomment/SKILL.md
git commit -m "feat(githubzak): add fixcomment skill"
```

---

## Task 5: Implement the answercomment skill

**Files:**
- Create: `plugins/githubzak/skills/answercomment/SKILL.md`

- [ ] **Step 1: Create the skill file**

Create `plugins/githubzak/skills/answercomment/SKILL.md` with this exact content:

```markdown
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

Parse `FILENAME` and `LINENUMBER`.

## Step 1 — Verify prerequisites and find PR

Run in sequence:
```bash
gh auth status
git branch --show-current
gh pr list --head <BRANCH> --state open --json number,url --jq '.[0]'
gh repo view --json owner,name --jq '{owner: .owner.login, repo: .name}'
```

Stop with a clear message if any step fails.

Store `BRANCH`, `PR_NUMBER`, `OWNER`, `REPO`.

## Step 2 — Find the comment

Fetch all inline review comments:
```bash
gh api "repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments"
```

Find the comment where:
- `path` ends with `<FILENAME>`
- `line` equals `<LINENUMBER>`, OR `original_line` equals `<LINENUMBER>` when `line` is null

**If no comment matches:** report "No inline comment found at `<FILENAME>:<LINENUMBER>`" and stop.

**If the user targets a general comment:** report "Only inline file comments can be answered with `/answercomment`. Use the GitHub web UI to reply to general PR comments."

**If multiple comments match:** list each with its body and ask the user to pick.

Store `COMMENT_ID` and `COMMENT_BODY`.

## Step 3 — Read code context

Read the file at `<FILENAME>` around `<LINENUMBER>` (10 lines either side) to understand what the comment refers to.

## Step 4 — Get GitHub username

```bash
gh api user --jq '.login'
```

Store as `GH_USERNAME`.

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

## Step 6 — Post the reply

```bash
gh api "repos/<OWNER>/<REPO>/pulls/comments/<COMMENT_ID>/replies" \
  -f body="<full reply text>"
```

Report the URL returned in the response (`html_url` field) so the user can verify the posted reply.
```

- [ ] **Step 2: Verify**

```bash
head -5 plugins/githubzak/skills/answercomment/SKILL.md
```

Expected:
```
---
name: answercomment
description: Use when the user runs /answercomment
```

- [ ] **Step 3: Verify complete plugin structure**

```bash
find plugins/githubzak -type f | sort
```

Expected:
```
plugins/githubzak/.claude-plugin/plugin.json
plugins/githubzak/skills/answercomment/SKILL.md
plugins/githubzak/skills/checkcomments/SKILL.md
plugins/githubzak/skills/cplb/SKILL.md
plugins/githubzak/skills/fixcomment/SKILL.md
```

- [ ] **Step 4: Commit**

```bash
git add plugins/githubzak/skills/answercomment/SKILL.md
git commit -m "feat(githubzak): add answercomment skill"
```
