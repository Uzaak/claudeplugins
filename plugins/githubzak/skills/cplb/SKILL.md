---
name: cplb
description: Use when the user runs /cplb with a branch name argument — creates or switches to the branch, commits all current changes with a generated message, pushes to remote, and opens a PR to main or master.
---

# githubzak: cplb — Commit, Push, Leave Building

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
