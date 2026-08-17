# Step-by-step: CI, tests, branch protection, templates & CLAUDE.md — v3
### For: mondeto-admin · mondeto · saluto · celo-org/mini-quiz · celo-org/x402-facilitator · celo-org/askbots · celo-org/celo-composer · celo-org/docs

Pairs with the `pm-kit` folder. Budget: ~1 hour to publish pm-kit as a repo (once), then 15 minutes per repo, plus the Claude Code test-writing sessions (Step 5).

---

## Step 0a — How this stays updated (read first)

**Don't copy the kit into eight repos — publish it once as `celo-org/pm-kit` and have repos point at it.** Otherwise you own eight drifting copies. Three mechanisms, each matched to what changes how often:

- **CI logic → reusable workflows.** Each repo has a 12-line `ci.yml` that just says `uses: celo-org/pm-kit/.github/workflows/ci-node.yml@main`. Change the steps in pm-kit; every repo runs the new version on its next PR. Zero per-repo work. (pm-kit can be internal/private since everything is in celo-org — enable Actions access "from repositories in the organization". Optionally tag `v1` and pin callers to it for stability.)
- **Templates and shared rules → sync PRs.** Issue forms, PR template, `engineering-rules.md`, `money-path-checklist.md`, `renovate.json` live under `pm-kit/templates/`. A workflow in pm-kit (`sync-templates.yml`, using `BetaHuhn/repo-file-sync-action`) opens a PR into every repo listed in `sync/sync.yml` whenever those files change on `main`. Auth comes from an org-owned GitHub App (client-ID variable + private-key secret on pm-kit; a short-lived token is minted per run). You review and merge those PRs like any other — which is also your audit trail of rule changes.
- **Claude commands → plugin marketplace.** `/file-issue`, `/write-pr`, `/review-pr`, `/post-merge` are a Claude Code plugin in pm-kit. Everyone installs once (`claude plugin marketplace add celo-org/pm-kit && claude plugin install pm-kit@pm-kit`) and gets updates with `claude plugin update pm-kit`.

The **only** files a repo owns are its `CLAUDE.md` (project description, commands, architecture, gotchas — it *imports* the shared rules with `@.claude/shared/engineering-rules.md`, so rules aren't restated per repo) and its CI caller's inputs (Node version, monorepo directory, dummy build env). Branch protection and labels are applied by script, idempotently — re-run whenever the ruleset changes.

**All eight repos are in celo-org — so why not `celo-org/.github`?** It already exists (Code of Conduct, CONTRIBUTING, SECURITY, a Renovate preset) and it is the default for all ~300 celo-org repositories that don't override it. Issue forms and a PR template placed there would apply to every team in the org — an org-level decision, not a team one. So templates are synced into our eight repos (scoped, reviewable as PRs). What being one org *does* buy: **one org-level ruleset** targeting the eight repos by name (`protection/org-ruleset-main.json` + `apply-org-ruleset.sh`, needs org admin) instead of eight per-repo rulesets, and pm-kit can be internal/private with "accessible from repositories in the organization" enabled for Actions. Reuse the org's Renovate preset (`celo-org/.github/renovate-config.json`) by extending it in `renovate.json` if it fits.

---

---

## Step 0 — Prerequisites (once)

Install and authenticate the GitHub CLI, and make sure Claude Code is set up:

```bash
gh auth login          # needs admin on the repos for branch protection
claude --version
```

Unzip the kit somewhere permanent, e.g. `~/claude-pm-kit/`.

---

## Step 1 — Apply the kit to each repo (~5 min per repo)

From each repo's root:

First publish pm-kit (once): create `celo-org/pm-kit`, push the folder, enable Actions org access, and wire the template-sync GitHub App (`TEMPLATE_SYNC_APP_CLIENT_ID` variable + `TEMPLATE_SYNC_APP_PRIVATE_KEY` secret). Then per repo:

```bash
cd ~/code/mondeto
git checkout -b lena/0-pm-kit-bootstrap   # <handle>/<issue>-<slug>
bash ~/code/pm-kit/apply.sh
```

The script detects the stack (Next.js/Node, Hardhat, Foundry, Python, Mintlify) and package manager, then adds — never overwriting: the thin CI caller `.github/workflows/ci.yml` (→ reusable workflow in pm-kit: lint + typecheck + tests + build, Node pinned from `.nvmrc`), `.github/ISSUE_TEMPLATE/` (bug / user story / task forms), `.github/PULL_REQUEST_TEMPLATE.md`, `.claude/shared/engineering-rules.md` + `money-path-checklist.md`, a `CLAUDE.md` skeleton that imports them, `renovate.json`, and — if the repo has no tests — a Vitest scaffold.

**Repo-specific notes:**

- **celo-composer** — already has good CI (`ci.yml`: lint, build, jest, CLI smoke test). The script will warn and skip it. Only take the templates + CLAUDE.md from the kit, plus a `verify-release-version` caller (it's a published npm package: tag must equal package.json version). Its CI job is named `test`, so either rename the job or set the ruleset context to `test` (Step 4). If it already has a `CLAUDE.md`, add the two `@.claude/shared/…` import lines to it.
- **celo-org/docs** — already has `docs-validation.yml` (Mintlify broken-links check). Take only the templates; a docs repo doesn't need unit tests. Its check name is `Check for broken links` — use that in the ruleset. Note this repo has a CODEOWNERS file; changes to `.github/` may need the listed owners' review.
- **mondeto-admin, mondeto, saluto** — Next.js on Node 24; the universal `ci.yml` handles them as-is. If `next build` needs env vars, pass dummy values via the caller's `build-env:` input (commented example in the file).
- **mini-quiz, x402-facilitator, askbots** — private, so I couldn't inspect them; the script's auto-detection handles whatever stack they are. If one is a monorepo, set `working-directory:` in the caller (or add one `ci` job per package). x402-facilitator is a money path — its `CLAUDE.md` gotchas should point at `money-path-checklist.md` explicitly.

Then fill in the `{{...}}` placeholders in `CLAUDE.md` (product description, architecture pointers, gotchas). Ten minutes per repo, and it's the highest-leverage file in the kit — every local Claude session and CI agent reads it. Or have Claude Code draft it: *"Read this codebase and fill in the placeholders in CLAUDE.md. Keep it under 80 lines."*

---

## Step 2 — Wire the scripts CI expects (~5 min per JS/TS repo)

CI fails deliberately if `lint` or `test` scripts are missing — that's the mechanism enforcing "every project covered by tests and linting." Make sure each `package.json` has:

```json
{
  "scripts": {
    "lint": "eslint .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  }
}
```

Where the kit added the Vitest scaffold, install the dev dependencies (the script prints the exact command for your package manager):

```bash
pnpm add -D vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/jest-dom @vitest/coverage-v8
```

Run `pnpm run test` locally — the included smoke test should pass. Commit, push, open the PR:

```bash
git add -A && git commit -m "chore: add CI, templates, CLAUDE.md"
gh pr create --fill
```

Watch the Actions tab — this first PR is your CI green light.

---

## Step 3 — Is protecting `main` necessary? (Yes — here's why and what)

**Yes, especially for you.** The moment agents open PRs and five people ship to five products, `main` is the only thing standing between "CI exists" and "CI matters." Unprotected, anyone (or any agent) can push straight to `main` and CI becomes advisory. Protection is what turns your tests and linting into a gate.

**Basic protection for a small team is four rules plus repo settings** (the kit's `ruleset-main.json` + `apply-protection.sh` contain precisely these — each one closes a class of incident we've actually hit):

1. **Require a pull request before merging, 1 approving review, stale approvals dismissed on push.** With 5 people, one approval is right. Dismiss-on-push means a Renovate re-roll to a new major can't ride on an approval written for the old one.
2. **Require the `ci` check to pass AND require the branch to be up to date with `main`** ("strict"). This is the one that matters most for you: a green check on a stale head no longer counts, and it mechanically forces the rebase between two lockfile PRs. The cost is one "Update branch" click per PR — worth it.
3. **Block force pushes.**
4. **Block branch deletion.**

(v2 also required review-thread resolution. Removed in v3 — see the contradictions log: mechanical thread resolution turns review hygiene into click-blocking. The enforcement is behavioural instead, and strict: a PR is not approved while any finding is open, however small, and every review point ends as a fix commit, a *filed* follow-up issue, or an explicit won't-do.)

Plus, in repo settings (the script does this): **squash merge only**, merge commits and rebase merges disabled, **PR title becomes the commit message**, PR body becomes the commit body, auto-merge enabled, delete branch on merge. That turns your squash convention from discipline into platform behaviour.

Skip (for now): code-owner reviews, signed commits, linear history. **Merge queue** is the one to add later: if the strict up-to-date rule starts costing you (>~5 concurrent PRs on shared files), merge queue does the up-to-date test automatically and removes the clicks.

**Plan check:** rulesets are enforced on private repos only on GitHub Team/Enterprise. celo-org is an organisation with ~300 repos and an org-level `.github`, so this is almost certainly covered — but verify once in Settings → Rules of any private repo (an unenforced ruleset shows an "upgrade" banner).

---

## Step 4 — Apply protection (~5 min total)

```bash
cd ~/code/pm-kit/protection
./create-labels.sh     celo-org/mondeto celo-org/mondeto-admin celo-org/saluto celo-org/mini-quiz celo-org/x402-facilitator celo-org/askbots celo-org/celo-composer celo-org/docs
./apply-org-ruleset.sh celo-org        # ONE org ruleset, targets the 8 repos by name (needs org admin)
./apply-protection.sh  celo-org/mondeto celo-org/mondeto-admin celo-org/saluto celo-org/mini-quiz celo-org/x402-facilitator celo-org/askbots celo-org/celo-composer celo-org/docs
#   ^ still needed for per-repo merge settings (squash-only, title=commit, auto-merge).
#     It also adds a per-repo ruleset; with the org ruleset in place that's redundant but harmless
#     (rules combine; the stricter wins). Set SKIP_REPO_RULESET=1 to apply only the merge settings.
```

If you don't have org admin for celo-org: `apply-protection.sh` alone does everything per repo — same protection, eight rulesets instead of one. Ask whoever administers celo-org for the org ruleset later; the JSON is ready to hand over.

**Check name matters:** with the reusable-workflow caller, GitHub names the check `ci / ci` (caller job / called job) — that's what `ruleset-main.json` requires. Confirm in the Checks tab of the first PR before applying; a wrong context makes every PR unmergeable.

(You need admin on each repo for merge settings and per-repo rulesets, and org admin for the org ruleset — if you lack it, `org-ruleset-main.json` is ready to hand to whoever has it.)

For **celo-composer** and **docs**, first edit `ruleset-main.json`'s `"context"` to their actual check name (`test` / `Check for broken links`).

Verify in each repo: Settings → Rules → Rulesets → `protect-main` shows Active. Then try `git push origin main` from a local clone — it should be rejected.

---

## Step 5 — Get proper tests into every project (the real work, agent-assisted)

The scaffold gives you a passing smoke test — a floor, not real coverage. Here's the pragmatic path for "proper tests right now" without a two-week testing detour:

**Priority order (per product):** 1) pure logic — money/points calculation, chain interaction helpers, data transforms — highest bug density, cheapest to test; 2) critical user paths as component tests (the one flow that, broken, means the product is down); 3) regression tests for every bug from now on (fix + failing-test-first). Skip for now: E2E browser suites, visual snapshots, coverage targets above ~50%.

**Let Claude Code write the first suite.** In each repo, run `claude` and use this prompt:

> Read CLAUDE.md and the codebase. Identify the 5 most bug-prone or business-critical modules (money handling, chain calls, state logic). Write Vitest tests for them: happy path, edge cases, and error handling. Use @testing-library/react for components. Don't test framework boilerplate. Run the suite until everything passes, then summarize what's covered and what the next 5 tests should be.

Review the tests like you'd review code — delete any that just restate the implementation. Expect 45–90 minutes per repo including review. Once a repo has a real suite, add a coverage threshold to `vitest.config.ts` (start at whatever it currently is, raise slowly).

**Ongoing enforcement is already in place:** the PR template's "tests added or updated" checkbox, CLAUDE.md's "every change ships with tests" rule, and CI failing without a test script.

---

## Step 6 — Make the agents actually follow the templates

Four mechanisms, all wired: the **issue forms** render as structured fields, so issues arrive uniform whether typed by a human or filed by an agent; **CLAUDE.md** imports the shared rules so every Claude session (local, Cowork, CI) reads the same playbook, with a ten-rule summary at the top for sessions that skim; the **PR template** auto-fills every PR body; and the **plugin commands** turn the playbook into procedure — `/file-issue` verifies before filing and clusters by fix boundary, `/write-pr` mutation-tests and decides Closes vs Refs from the acceptance boxes, `/review-pr` tiers the review and runs the behaviour pass, `/post-merge` checks what actually closed. Every command shows its output and waits for your confirmation before touching GitHub.

Two habits to add on the human side: when the research person generates stories with Claude, end the prompt with *"file each story as a GitHub issue following .github/ISSUE_TEMPLATE/user_story.yml, in the celo-org/<repo> repo"* — the acceptance-criteria field is what makes stories executable by builders and agents alike. The label set is created by `protection/create-labels.sh` (Step 4) so agents never invent labels.

---

## Step 6b — One rulebook: what's in it and the close calls

The team's accumulated playbooks are merged into **`templates/.claude/shared/engineering-rules.md`** — one document, synced to every repo, imported by every `CLAUDE.md`. Its §9 records the close calls; the decisions, briefly:

- **Branch names**: `<handle>/<issue>-<slug>` — the type prefix is dropped because it already lives in the Conventional-Commit title; the handle answers "whose is this", the issue number links branch → ticket.
- **"Squash to logical commits with trailers"** vs one-commit squash-merge: the PR *body* is the commit message on `main` (repo setting), so rationale/verification/limits/trailers live there — same content, the place the platform preserves.
- **Issue granularity**: not a real conflict once you separate the two tests — *same-diff* (merge tickets the same diff would close) and *different-schedule* (split items that would be prioritised differently). Both are in the rules and in `/file-issue`.
- **Required thread resolution** vs **approve-with-nits**: dropped both — no ruleset click-blocking, and no approving over open nits. Every finding is fixed on the PR or lands in a filed issue before approval.
- **Strict up-to-date** vs **parallelism tax**: kept strict — stale-head merges have broken production; the tax is a click. Merge queue is the escape hatch when the queue gets deep.
- **Squash-only** vs **stacked PRs**: kept squash; stacks ≤ 2 deep, second-lander rebases `--onto main`.
- **P0/P1/P2** vs **`priority:*`**: `priority:critical|high|medium|low`, with critical defined.
- **"Never silent force-push"** vs squash culture: force-pushing your own PR branch is fine; announcing what changed is the rule.
- **Uniform max-rigour review** vs cost: tiered — mechanical gets read + CI; logic/money/wallet gets run-it-and-refute. Real CI is what makes the light tier safe, which is why CI is Step 1.

The rules also encode the agent-era practices: the feedback-resolution protocol (reproduce → fix → audit your own fix → report what it taught → push back only with a measurement → defer ownership calls), seam tests over unit tests, guarantee-on-every-path, error-body leakage, read bounds on write paths, config-safety rules, judgement-calls section in the PR template, CI proven in both directions, strike-through-never-delete for wrong claims, SHA-pinned prior art, and `/close-pr` for capturing value from unmerged work.

**Tester mode** — born from our first real-money payout, which surfaced three bugs no offline test could reach — is a generic shared pattern: two DB flags, server-side gating at every surface, downstream flag-blind, verify at the source of truth, with a porting checklist for the other products. The money-path checklist asks "has it run in anger?" before any real-money path goes public.

The 18-item **money-path checklist** (payout parity, fee omission, self-referential verification, and the rest) is its own synced file, referenced from the PR template and `/review-pr`.

Two lessons became CI code rather than prose: Node is pinned from `.nvmrc` (a floating runner version once turned main red with no commit behind it), and typecheck uses `npx --no-install tsc` (npm's placeholder package named `tsc` once certified 21 syntax errors as a passing "TypeScript check").

---

## Step 7 — Verify (15 min, once everything is in)

Per repo, confirm: a test PR shows the template pre-filled; "New issue" shows the three forms and no blank-issue option; CI runs on the PR and `ci` appears as a required check; merging is blocked until CI is green + 1 approval; direct push to `main` is rejected; `CLAUDE.md` placeholders are filled in.

## Rollout order (next week)

Day 0 (½ day): publish pm-kit as a repo, PAT secret, install the plugin. Day 1: mondeto end-to-end (bootstrap + scripts + labels + protection + first Claude test session) — your reference repo; confirm the `ci / ci` check name there before applying protection anywhere else. Day 2: mondeto-admin + saluto (copy the pattern). Day 3: the three private celo-org repos. Day 4: templates + CLAUDE.md for celo-composer and docs (CI already exists there); protection everywhere. Day 5: Claude Code test-writing sessions for whichever repos still only have smoke tests.
