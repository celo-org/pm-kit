# pm-kit — one place for CI, templates, rules, and Claude commands across all repos

Repos don't copy this kit; they **point at it**. Change something here, and it reaches every repo:

| What | Lives in pm-kit | In each repo | How updates propagate |
|---|---|---|---|
| CI steps (lint, typecheck, test, build) | `.github/workflows/ci-*.yml` (reusable, `workflow_call`) | 12-line caller `.github/workflows/ci.yml` → `uses: celo-org/pm-kit/...@main` | Instantly — callers run whatever is on `main` here |
| Issue forms, PR template, shared rules, money-path checklist, renovate.json | `templates/` | `.github/…`, `.claude/shared/…` | `sync-templates.yml` opens a PR in every repo listed in `sync/sync.yml` |
| Claude commands `/file-issue` `/write-pr` `/review-pr` `/post-merge` `/close-pr` | `claude-plugin/` (plugin marketplace) | installed plugin | `claude plugin update pm-kit` |
| Branch protection | `protection/org-ruleset-main.json` — **one org-level ruleset** targeting the 8 repos by name | — | edit the include list, re-run `apply-org-ruleset.sh` |
| Merge settings (squash-only, title=commit, auto-merge) + labels | `protection/apply-protection.sh`, `create-labels.sh` | per-repo settings via API | re-run (idempotent) |
| `CLAUDE.md` | `templates/CLAUDE.md.template` (starter only) | **repo-owned** — imports the synced shared rules with `@.claude/shared/engineering-rules.md` | manual; only project-specific content lives there |

## Setup (once)

1. Create this as `celo-org/pm-kit`. All target repos are in celo-org, so it can be **internal or private** — just enable Settings → Actions → General → Access: "Accessible from repositories in the organization" so the reusable workflows can be called. **Caveat: PUBLIC repos cannot call reusable workflows in an internal/private pm-kit** (GitHub restriction, the access setting cannot override it) — if any target repo is public, pm-kit must be public too, or that repo keeps a self-contained CI workflow.
2. Wire the template-sync GitHub App (org-owned, no expiry): add repository variable `TEMPLATE_SYNC_APP_CLIENT_ID` and repository secret `TEMPLATE_SYNC_APP_PRIVATE_KEY` (the app's full PEM). The app needs Contents RW + Pull requests RW and must be installed on the target repos.
3. Pin the reusable workflow ref: `@main` is convenient; for stability tag releases (`v1`) and point callers at `@v1`.

## Team setup (each person, ~2 min)

Everything in this kit is repo-level except one thing: the Claude commands are installed per person.

1. Prereqs: [Claude Code](https://claude.com/claude-code) and the [GitHub CLI](https://cli.github.com) (`gh auth login`).
2. Install the commands:
   ```bash
   claude plugin marketplace add celo-org/pm-kit
   claude plugin install pm-kit@pm-kit
   ```
3. Verify: run `claude` in any repo and type `/` — you should see `/file-issue`, `/write-pr`, `/review-pr`, `/post-merge`, `/close-pr`.
4. Later updates: `claude plugin update pm-kit`.

That's it — CI, templates, shared rules, and branch protection are already wired into the repos and need no per-person configuration.

## Bootstrap a repo

```bash
cd ~/code/<repo> && git checkout -b <handle>/pm-kit-bootstrap
bash ~/code/pm-kit/apply.sh
```
Then: fill in `CLAUDE.md`, ensure `lint`/`test`/`typecheck` scripts exist, open the PR. Then labels + protection:
```bash
bash pm-kit/protection/create-labels.sh owner/repo
bash pm-kit/protection/apply-org-ruleset.sh          # once, org-level (needs org admin)
bash pm-kit/protection/apply-protection.sh owner/repo   # per-repo merge settings
```
And the plugin: `claude plugin marketplace add celo-org/pm-kit && claude plugin install pm-kit@pm-kit`.

## Files

- `.github/workflows/` — reusable CI (`ci-node`, `ci-hardhat`, `ci-foundry`, `ci-python`, `ci-docs-mintlify`), `verify-release-version`, `sync-templates`
- `callers/` — thin per-repo workflows
- `templates/` — everything synced into repos, plus `CLAUDE.md.template`
- `templates/.claude/shared/engineering-rules.md` — the merged playbook (issues, PRs, tests, reviews, merging, closing, contradictions log)
- `templates/.claude/shared/money-path-checklist.md` — 18 recurring defects for money/security diffs
- `templates/.claude/shared/tester-mode-pattern.md` — run real-money paths in production behind a restricted audience; porting checklist
- `claude-plugin/` — commands; `.claude-plugin/marketplace.json` — marketplace manifest
- `protection/` — `org-ruleset-main.json` + `apply-org-ruleset.sh` (one org ruleset), `ruleset-main.json` + `apply-protection.sh` (per-repo fallback + merge settings), `create-labels.sh`
- `testing/` — Vitest scaffold for repos with zero tests
- `SETUP-GUIDE.md` — the step-by-step walkthrough

## Why not `celo-org/.github`?

It exists and is the org-wide default for ~300 repositories (Code of Conduct, CONTRIBUTING, SECURITY, Renovate preset). Anything placed there — issue forms, PR template — becomes the default for every celo-org repo without its own. Our templates are team conventions, so they're synced into our eight repos instead. Two things from the org repo we *should* reuse rather than duplicate: its `renovate-config.json` preset (extend it in our `renovate.json` instead of `config:recommended` if the org preset fits) and `SECURITY.md`/`CONTRIBUTING.md`, which repos inherit automatically.
