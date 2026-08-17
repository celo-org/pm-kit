---
description: Open a PR for the current branch with a body that meets the playbook bar. Usage: /write-pr [issue number]
allowed-tools: Bash(gh *), Bash(git *), Bash(pnpm *), Bash(npm *), Bash(yarn *), Bash(bun *), Read, Grep, Glob
---

Issue (if given): $ARGUMENTS

Follow `.claude/shared/engineering-rules.md` §2 (PRs) and §3 (Verification). Steps:

1. `git diff main...HEAD --stat` and read the diff. Confirm it is **one concern**. If it's more, tell me and propose a split before continuing.
2. Run lint, typecheck, and tests locally on this head. Confirm at least one test goes THROUGH the seam this change touches (route/CLI/component), not only pure functions; and that every guarantee you're about to claim in prose has a test on its failure path. Then **mutation-test**: temporarily revert the core fix, run tests, count how many go red, restore. If zero go red, stop and tell me — the change ships without the test that would catch it.
3. Determine `Closes` vs `Refs`: read the linked issue's acceptance criteria. `Closes #N` only if EVERY box is met by this diff; otherwise `Refs #N` and list which boxes this closes and which stay open.
4. Check for conflicts with open PRs on the same files: `gh pr list --json number,headRefName,files` and `git merge-tree`. If overlaps exist, state them and propose a merge order.
5. List judgement calls the issue left open that you decided (decision, reasoning, reversal cost) and any product change bundled with the fix — flag for the maintainer. If this touches CI, get one green and one deliberately red run to link.
6. Grep for docs/runbook drift: README, DEPLOYMENT/runbook, `.env.example`, examples, error strings that describe the old behaviour. Update them in this PR.
7. Title: Conventional Commits, scoped, imperative, outcome-stated — this becomes the commit on `main`.
8. Body, using `.github/PULL_REQUEST_TEMPLATE.md`, must contain: summary of what it ACTUALLY does · Closes/Refs · **what this does NOT do / residual risk (with numbers)** · **judgement calls** · stacked-on / independent-of · verification evidence as commands + output (including the mutation count) · remaining ops steps as checkboxes · questions for the maintainer marked at the end.
9. Show me title + body. **Do not open the PR until I confirm.** After opening, if the ruleset requires up-to-date, run `gh pr update-branch` if behind.
