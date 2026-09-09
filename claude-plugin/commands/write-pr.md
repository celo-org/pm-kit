---
description: Open a PR for the current branch with a body that meets the playbook bar. Usage: /write-pr [issue number]
allowed-tools: Bash(gh *), Bash(git *), Bash(pnpm *), Bash(npm *), Bash(yarn *), Bash(bun *), Read, Grep, Glob, mcp__plugin_pm-kit_playwright
---

Issue (if given): $ARGUMENTS

Follow `.claude/shared/engineering-rules.md` §2 (PRs) and §3 (Verification). Steps:

1. `git diff main...HEAD --stat` and read the diff. Confirm it is **one concern**. If it's more, tell me and propose a split before continuing.
2. Run lint, typecheck, and tests locally on this head. Confirm at least one test goes THROUGH the seam this change touches (route/CLI/component), not only pure functions; and that every guarantee you're about to claim in prose has a test on its failure path. Then **mutation-test**: temporarily revert the core fix, run tests, count how many go red, restore. If zero go red, stop and tell me — the change ships without the test that would catch it.
2b. **Browser pass — mandatory when the diff touches anything rendered** (`app/`, `pages/`, `components/`, styles, copy, routes, the wallet/provider tree); otherwise write "no UI surface — browser pass skipped" and go on. This is level one of two (§3): you drive the browser and fix what you find; the maintainer's own click-through is level two and should find nothing.
   - Start the dev server in the background (`<pm> run dev`) and wait for the port.
   - Per changed surface, with the Playwright tools: `browser_navigate` → `browser_snapshot` → exercise the changed interaction (`browser_click`, `browser_fill_form`; the §3 edge classes: empty input, Unicode, double-submit) → `browser_console_messages` (count errors) → `browser_network_requests` (failed same-origin requests) → `browser_take_screenshot` with `filename` `<branch>-<surface>-desktop.png`. Then `browser_resize` to a phone viewport (412×915) and screenshot again — every product is mobile-first.
   - Payment surface, bigger change (new flow, changed amounts, recipients, or fee logic): offer one real on-chain transaction as **optional** evidence — I run the flow once from my own wallet with a small amount and give you the tx hash; you verify the receipt at the chain and put hash + status in the body. Never ask me for a key, and never paste one. Small fixes on a payment path don't need this; say which case this is.
   - Loop: fix → re-run the affected surface → until console errors are zero and the surface does what the issue says. After a handful of rounds, stop and list what is still wrong as a residual in the body — never omit it.
   - Evidence for step 8: routes visited, actions performed, console-error count, screenshot paths (I attach the images when I confirm), and the on-chain tx hash + receipt status if one was provided. Scope it honestly: "true of what I ran locally" is not "true of the preview".
3. Determine `Closes` vs `Refs`: read the linked issue's acceptance criteria. `Closes #N` only if EVERY box is met by this diff; otherwise `Refs #N` and list which boxes this closes and which stay open.
4. Check for conflicts with open PRs on the same files: `gh pr list --json number,headRefName,files` and `git merge-tree`. If overlaps exist, state them and propose a merge order.
5. List judgement calls the issue left open that you decided (decision, reasoning, reversal cost) and any product change bundled with the fix — flag for the maintainer. If this touches CI, get one green and one deliberately red run to link.
6. Grep for docs/runbook drift: README, DEPLOYMENT/runbook, `.env.example`, examples, error strings that describe the old behaviour. Update them in this PR.
7. Title: Conventional Commits, scoped, imperative, outcome-stated — this becomes the commit on `main`.
8. Body, using `.github/PULL_REQUEST_TEMPLATE.md`, must contain: summary of what it ACTUALLY does · Closes/Refs · **what this does NOT do / residual risk (with numbers)** · **judgement calls** · stacked-on / independent-of · verification evidence as commands + output (including the mutation count, and for a UI surface the browser-pass evidence from 2b: routes, actions, console-error count, screenshots, optional tx hash) · remaining ops steps as checkboxes · questions for the maintainer marked at the end.
9. Show me title + body. **Do not open the PR until I confirm.** After opening, if the ruleset requires up-to-date, run `gh pr update-branch` if behind.
