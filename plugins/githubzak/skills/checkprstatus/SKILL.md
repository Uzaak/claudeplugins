---
name: checkprstatus
description: Use when the user runs /checkprstatus — inspects CI/CD pipeline status for the current branch's open PR and reports what is passing, pending, needs approval, or failing with error details.
---

# githubzak: Check PR Status

Inspect all CI checks on the current branch's open PR and report what is passing, pending, needs input, or failing with details.

## Step 1 — Verify prerequisites

Check that `gh` is available and authenticated:

```bash
gh auth status
```

If this fails, report the error and stop. Do not proceed without a working `gh` session.

## Step 2 — Get current branch and find PR

```bash
BRANCH=$(git branch --show-current)
```

If `BRANCH` is empty (detached HEAD), report "Not on a named branch — cannot look up a PR" and stop.

```bash
PR_NUMBER=$(gh pr list --head <BRANCH> --state open --json number --jq '.[0].number')
PR_URL=$(gh pr list --head <BRANCH> --state open --json url --jq '.[0].url')
```

If `PR_NUMBER` is empty or null, report "No open PR found for branch `<BRANCH>`" and stop.

## Step 3 — Get owner and repo

```bash
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
```

## Step 4 — Get detailed check run statuses

```bash
gh api "repos/<OWNER>/<REPO>/commits/$(git rev-parse HEAD)/check-runs?per_page=50" \
  --jq '.check_runs[] | {name,status,conclusion,url: .html_url}'
```

## Step 5 — Classify each check

| Condition | Classification |
|-----------|---------------|
| `conclusion == "success"` | ✅ Pass |
| `status == "in_progress"` | 🔄 Running |
| `status == "queued"` | ⏳ Queued |
| `conclusion == "failure"` | ❌ Failed |
| `conclusion == "action_required"` | 🔐 Needs approval |
| Name contains `approve`, `hold`, `manual` and status is `pending` | 🔐 Needs approval |

## Step 6 — For failed jobs, fetch failure details

```bash
gh api "repos/<OWNER>/<REPO>/commits/<SHA>/check-runs?per_page=50" \
  --jq '.check_runs[] | select(.conclusion == "failure") | {name, details_url}'
```

The `output.summary` field often contains the failure reason:

```bash
gh api "repos/<OWNER>/<REPO>/check-runs/<RUN_ID>" \
  --jq '{name, conclusion, output: .output.summary}'
```

## Step 7 — Report

Print PR URL first, then a grouped status table:

```
PR: <URL>

✅ Passing:    unit-test, sonarqube, bearer, slack-notify-hold-hotfix
🔄 Running:    ecr-build-and-push-amd64, ecr-build-and-push-arm64
🔐 Approved:   deployment-flow/approve-to-qa
❌ Failed:     (none)

Overall: deployment-flow is IN PROGRESS — waiting for ECR builds to complete.
```

If anything needs approval, call it out explicitly:

```
🔐 ACTION REQUIRED: Job "approve-to-qa" is waiting for manual approval.
   Approve at: <CircleCI URL>
```

If anything failed, include what went wrong:

```
❌ FAILED: unit-test
   Reason: <summary from check output or CircleCI URL for full log>
```

## Common Patterns

**Hotfix/release branch flow** — expect this sequence:
1. `unit-test`, `sonarqube`, `bearer` run in parallel
2. `slack-notify-hold-hotfix` fires — human approval gate
3. After approval: ECR builds (amd64 + arm64)
4. Deploy to QA, then Live

**All green but deployment blocked** — look for a `hold` or `approve-to-*` job in `pending` state; someone needs to click approve in CircleCI.

**Workflow-level check vs job-level checks** — `gh pr checks` shows both. The top-level `deployment-flow` check reflects the whole workflow; individual `ci/circleci: <job>` entries show per-job status. Both are useful.
