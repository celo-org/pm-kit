---
description: Review a PR by attempting to refute it with the code running, tiered by risk. Usage: /review-pr <PR number>
allowed-tools: Bash(gh *), Bash(git *), Bash(pnpm *), Bash(npm *), Bash(yarn *), Bash(bun *), Read, Grep, Glob, mcp__plugin_pm-kit_playwright
---

Review PR #$ARGUMENTS following `.claude/shared/engineering-rules.md` §4 (Reviewing).

**Setup — review the right thing**
1. **Pin the head mechanically. This is a gate, not a note — if it does not pass, stop and re-fetch.** Never review a ref fetched earlier in the session: re-fetch immediately before checkout and compare against the API's answer.

   ```bash
   PR=$ARGUMENTS
   API=$(gh pr view "$PR" --json headRefOid -q .headRefOid)
   git fetch origin --force "refs/pull/$PR/head:refs/remotes/pr/$PR"
   LOCAL=$(git rev-parse "refs/remotes/pr/$PR")
   [ "$API" = "$LOCAL" ] || { echo "STALE: API=$API LOCAL=$LOCAL"; exit 1; }
   echo "reviewing #$PR at $API"
   ```

   Check out `refs/remotes/pr/$PR` — by that SHA, not a branch name and not a previously fetched ref. A stale review is internally consistent and every finding in it is true of *something*, so this failure has no symptom from the inside; the comparison is the only thing that catches it.

   Then `gh pr view $ARGUMENTS --json baseRefName,files,body,title` and check whether the branch is behind `main` (`git rev-list --count refs/remotes/pr/$PR..origin/main`); if it is, review against current main, not the base it was written on.
2. Is `main` currently red? If so, first ask what moved before blaming this PR.

**Tier it**
- *Mechanical* (renames, quoting, doc paths, deps bump with green CI): read the diff + confirm what CI actually ran. Skip the behaviour pass. Say you tiered it down.
- *Logic / new surface / anything touching funds, security, release, wallet tree — or anything rendered*: full pass below. A UI surface makes the browser pass (step 5) part of the behaviour pass, not an optional extra.

**Behaviour pass (logic tier — non-negotiable)**
3. Check out the pinned ref from step 1 (never a branch name — it can move under you). Run the suite, and record the totals; they go at the top of the review. For every new/changed test ask "what would make this go red?" and prove it can — revert the fix, run, count red. A suite equally green with and without the fix proves nothing.
4. Build the real artifact (for a scaffolder: scaffold the affected templates and build the generated project — the generated output IS the product). For a web app: build; if it touches the wallet/provider tree, the browser pass in step 5 must cover a normal browser on desktop and phone — MiniPay itself is the human's level-two pass, say so in the review.
5. **Browser pass — refute the UI with the tool, not by reading JSX.** Prefer the Vercel preview built from this head, it is the artifact a user gets: `gh api "repos/{owner}/{repo}/deployments?sha=$API"` → `…/deployments/<id>/statuses` → `environment_url`. Fall back to a dev server on the pinned checkout (also when the preview is behind Vercel Authentication and you have no bypass) — and say which you used. Per changed surface, with the Playwright tools: `browser_navigate` → `browser_snapshot` → exercise the changed interaction and try to break it (empty input, Unicode, double-click submit, back button) → `browser_console_messages` → `browser_network_requests` → `browser_take_screenshot`, on desktop and again after `browser_resize` to a phone viewport (412×915). Verify the author's screenshots against what you see, not against the body (7b applies to images). For a CLI, run the command a user would run and read what they'd see. Then `gh pr checks $PR`: quote the `e2e-smoke` result for this head; if it did not run (no caller on the branch, deploy failed), say so instead of implying coverage. Payment path with a bigger change (new flow, amounts, recipients, fee logic): if the body carries a tx hash, verify the receipt at the chain yourself (`cast receipt` / `eth_getTransactionReceipt`: status, from, to, value) and say what matched; if it doesn't, request one as **optional** evidence in the review — a real small-amount transaction from the author's own wallet — and state plainly that the review covered the code and the browser pass but not a live send.
6. If it touches money/security paths, run `.claude/shared/money-path-checklist.md` item by item. If the repo has a tester-mode audience flag, `grep -r` it: it must not appear downstream of access control (scheduler, scoring, payout, workers) — that's a finding. If this PR takes a real-money/real-send path public, ask whether it ran in production behind tester mode first.
7. **Recompute the math** — pinned constants, thresholds, formulas: rederive independently. Probe edge classes (Unicode/empty input, band between two thresholds, `>=` vs `>`, concurrent duplicates) and the fail-open/fail-closed direction of every guard. Audit 4xx/5xx bodies for leaks; check read bounds on write paths.
7b. **Verify every claim in the PR body against the code, not against the body** — a PR description is testimony, not evidence; find where the narrative outran the code. Half-wrong claims: identify the right half. Test doubles: do fakes honour their arguments? Absence-assertions: paired with a control that proves the code ran?

**Output**
7c. If CI is red, say which failures are code and which are infra/permissions.
7c-bis. **Re-assert the head immediately before posting** — re-run the step-1 gate. A review can be correct for the SHA it ran on and stale by the time it lands; branches move during long reviews. If the head has moved, either re-run against the new head or open the review with an explicit `reviewed at <sha>, branch has since moved to <sha>` line. A review silently stamped with a SHA it did not read is worse than a late one.
7d. **Money / auth / anything moving value: adversarially verify your own findings** — a second independent pass trying to refute each one — before drafting. Plausible-but-wrong findings burn author trust.
8. Verdict: `APPROVE` (zero open findings, however small) / `REQUEST-CHANGES` (anything else). There is no approve-with-nits: a PR is not good to merge while any finding is unresolved. A finding resolves as exactly one of (a) a fix commit on this PR, or (b) — only when it is genuinely out of scope for this PR — a follow-up issue that gets *filed*, not merely suggested. "Could be a new ticket" or "out of scope" written in prose, with no issue behind it, leaves the finding open. Re-verify the highest-severity finding line-by-line before requesting changes.
9. **Open the review with the head SHA and the evidence counts you observed** — suite totals, mutation counts, what you built, what you clicked: `head 4af2b310 · 212/212 · typecheck and ESLint clean · browser pass 4 routes, 0 console errors · e2e-smoke green`. This is not decoration. A count that does not match the author's branch is the only signal a stale review emits, and it is what lets them catch it in one glance instead of re-proving fixes they already shipped.
9-bis. Findings, severity-ordered, each with: severity · `file:line` · one-sentence defect · concrete failure scenario · suggested fix. Every finding includes the shape of the fix ("one line: strip the flag when block is true"). Then a **verified-good** section (what you checked and found sound) and **what the PR got right**; say whether it's "one round of targeted fixes" or a rethink. Then merge-order hazards (shared files, squash retargeting of stacks, signature changes).
10. For every finding you propose to defer as out of scope: write the complete issue (title + body following `.github/ISSUE_TEMPLATE/`, `Refs` the PR) — it gets filed with `gh issue create` alongside posting the review, and the review links the issue number next to the finding.
11. Show me the review and every issue to be filed. **Do not post the review or file the issues until I confirm.**
