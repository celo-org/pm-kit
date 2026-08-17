---
description: Review a PR by attempting to refute it with the code running, tiered by risk. Usage: /review-pr <PR number>
allowed-tools: Bash(gh *), Bash(git *), Bash(pnpm *), Bash(npm *), Bash(yarn *), Bash(bun *), Read, Grep, Glob
---

Review PR #$ARGUMENTS following `.claude/shared/engineering-rules.md` §4 (Reviewing).

**Setup — review the right thing**
1. `gh pr view $ARGUMENTS --json headRefOid,baseRefName,files,body,title`. Note the head SHA; `gh pr diff` can serve stale content — confirm you're reading that SHA. Check whether the branch is behind `main` (`git fetch && git rev-list --count HEAD..origin/main` on the branch); if it is, review against current main, not the base it was written on.
2. Is `main` currently red? If so, first ask what moved before blaming this PR.

**Tier it**
- *Mechanical* (renames, quoting, doc paths, deps bump with green CI): read the diff + confirm what CI actually ran. Skip the behaviour pass. Say you tiered it down.
- *Logic / new surface / anything touching funds, security, release, wallet tree*: full pass below.

**Behaviour pass (logic tier — non-negotiable)**
3. Check out the branch. Run the suite. For every new/changed test ask "what would make this go red?" and prove it can — revert the fix, run, count red. A suite equally green with and without the fix proves nothing.
4. Build the real artifact (for a scaffolder: scaffold the affected templates and build the generated project — the generated output IS the product). For a web app: build; if it touches the wallet/provider tree, load in a normal browser AND MiniPay.
5. Click-through: exercise the changed user-facing surface once (dev server / CLI command a user would run) and read what they'd see.
6. If it touches money/security paths, run `.claude/shared/money-path-checklist.md` item by item. If the repo has a tester-mode audience flag, `grep -r` it: it must not appear downstream of access control (scheduler, scoring, payout, workers) — that's a finding. If this PR takes a real-money/real-send path public, ask whether it ran in production behind tester mode first.
7. **Recompute the math** — pinned constants, thresholds, formulas: rederive independently. Probe edge classes (Unicode/empty input, band between two thresholds, `>=` vs `>`, concurrent duplicates) and the fail-open/fail-closed direction of every guard. Audit 4xx/5xx bodies for leaks; check read bounds on write paths.
7b. **Verify every claim in the PR body against the code, not against the body** — a PR description is testimony, not evidence; find where the narrative outran the code. Half-wrong claims: identify the right half. Test doubles: do fakes honour their arguments? Absence-assertions: paired with a control that proves the code ran?

**Output**
7c. If CI is red, say which failures are code and which are infra/permissions.
7d. **Money / auth / anything moving value: adversarially verify your own findings** — a second independent pass trying to refute each one — before drafting. Plausible-but-wrong findings burn author trust.
8. Verdict: `APPROVE` / `APPROVE-WITH-NITS` (= mergeable now; nits are not soft blockers) / `REQUEST-CHANGES` (only with a concrete blocking item). Re-verify the highest-severity finding line-by-line before requesting changes.
9. Findings, severity-ordered, each with: severity · `file:line` · one-sentence defect · concrete failure scenario · suggested fix. Every finding includes the shape of the fix ("one line: strip the flag when block is true"). Then a **verified-good** section (what you checked and found sound) and **what the PR got right**; if requesting changes, say whether it's "one round of targeted fixes" or a rethink. Then merge-order hazards (shared files, squash retargeting of stacks, signature changes).
10. For every nit that doesn't block: draft the follow-up issue (title + body) so it doesn't evaporate at merge time.
11. Show me the review. **Do not post it until I confirm.**
