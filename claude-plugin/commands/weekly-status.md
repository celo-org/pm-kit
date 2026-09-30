---
description: Draft the weekly per-product status from the board, merged PRs, and what is actually deployed. Usage: /weekly-status [since date, default last Friday]
allowed-tools: Bash(gh *), Bash(jq *), Bash(date *), Bash(curl *), Bash(npm view *), Read
---

Window: $ARGUMENTS (default: since last Friday)

Follow `.claude/shared/engineering-rules.md` §1 for the evidence bar — every line here is something you ran, not something you inferred.

Draft the Friday status. **Under 300 words total.** It is read by people who will not open the board; it exists so nobody has to hold the overview in their head. You draft, a human edits — do not post it anywhere.

## 0. Resolve the window

If `$ARGUMENTS` is empty, compute last Friday portably (`date -d` is GNU-only and fails on macOS):
```
SINCE=$(date -v-fri +%F 2>/dev/null || date -d 'last friday' +%F)
```
These disagree on a Friday — BSD returns today, GNU returns a week ago. State the resolved date at the top of the status, and if today is Friday say which reading you used.

## 1. Gather (evidence, not impressions)

Per repo on the board:
```
gh pr list --state merged --search "merged:>=<since>" --json number,title,mergedAt,url,labels
gh issue list --state closed --search "closed:>=<since>" --json number,title,url
gh issue list --state open --label "priority:critical" --json number,title,url,updatedAt
gh pr list --state open --json number,title,isDraft,reviewDecision,updatedAt,url
```
Plus, if the repo is on the project board, items whose Status is blocked/in-review, and anything with a Target date inside the next two weeks.

## 1b. Deployment currency (every run, every repo)

A merged PR that nobody deployed is not shipped. Every week, for every repo, establish what serves users and whether it is the default branch's HEAD. Not every product deploys the same way, so pick the check by hosting — and when nothing is observable, say so rather than guessing.

Resolve the default branch first; never assume `main` (faucet's is `master`):
```
DEF=$(gh api repos/celo-org/$r --jq .default_branch)
HEAD=$(gh api repos/celo-org/$r/commits/$DEF --jq .sha)
```

**a. GitHub Deployments (Vercel git integration, GitHub Pages, Mintlify).** List environments, drop `Preview*` and `CI/CD`; a repo may have several production projects (mini-quiz has two), and a name can mislead (docs' only environment is `staging` and its `environment_url` is docs.celo.org — go by the URL):
```
gh api "repos/celo-org/$r/deployments?per_page=100" --jq '[.[].environment]|unique'
id=$(gh api -X GET repos/celo-org/$r/deployments -f environment="<env>" -F per_page=1 --jq '.[0].id')   # -f encodes the spaces in "Production – mini-quiz"
gh api repos/celo-org/$r/deployments/$id --jq '.sha'
gh api repos/celo-org/$r/deployments/$id/statuses --jq '.[0] | "\(.state) \(.environment_url) \(.log_url)"'
gh api repos/celo-org/$r/compare/<deployed-sha>...$HEAD --jq '.ahead_by'
```
`ahead_by > 0`, or state not `success` ⇒ **behind**.

**b. Deploy workflow (droplet via Actions, e.g. saluto's `deploy.yml`).** Same repo may also have a Vercel frontend — check both:
```
gh api repos/celo-org/$r/contents/.github/workflows --jq '.[].name' | grep -i deploy
gh run list -R celo-org/$r --workflow deploy.yml --branch $DEF --limit 10 --json headSha,conclusion,createdAt --jq 'sort_by(.createdAt)|last'   # sort yourself: --limit 1 has returned a stale run
```
`headSha` ≠ `$HEAD`, or conclusion not `success` ⇒ **behind**.

**c. Published package (celo-composer, buy-skill).** Registry vs the manifest on the default branch:
```
npm view <package> version
gh api repos/celo-org/$r/contents/package.json?ref=$DEF --jq .content | base64 -d | jq -r .version
```

**d. Nothing observable (x402-facilitator: manual `docker compose` on a droplet, `/health` carries no commit).** Write "deployed commit not observable from GitHub". If the product has a public URL, probe one endpoint per feature merged in the window with `curl` and record the result as evidence **for that feature only** — a green probe never licenses "on main". Example: `/supported`, `/mcp`, `/.well-known/agent-registration.json` on api.x402.celo.org.

**e. Nothing deploys (celopedia-skills).** One word: n/a.

### Make sure the latest is released

A behind or failed product goes in the **Deployments** block *and* under **Decisions needed**, with the exact remedy and an owner. Draft the remedy as a runnable command; **run it only after the user confirms in chat** (rules §2: propose, never execute, anything outward-facing). Then re-run the check for that repo and print the new line — the status ships with the post-remedy state.

| Hosting | Situation | Remedy |
|---|---|---|
| Deploy workflow | run missing or failed for HEAD | `gh workflow run deploy.yml -R celo-org/<repo> --ref <default-branch>`, then re-check b |
| Vercel git integration | latest production deployment `failure`/`error` | open `log_url`; this is a fix-forward, not a redeploy — point at or file the issue |
| Vercel git integration | no production deployment for HEAD at all (ignored build step, paused project, production branch ≠ default) | print `vercel redeploy <last-prod-url> --prod --scope <team>` or the dashboard Redeploy; the plugin does not ship the Vercel CLI, so this one is handed over, not run |
| Published package | registry behind manifest | propose the release tag push; `verify-release-version` refuses a tag that disagrees with package.json |
| Droplet, manual | unobservable | print the repo's `docs/DEPLOYMENT.md` step and list under Blocked with who has box access |

## 2. Rules for what you write

- **Shipped** = merged to the default branch in the window. A merged PR is not "shipped to users" unless it was deployed — say which. The Deployments block (§1b) is what licenses the word "deployed" in a product section: if it says behind, write "merged, not yet deployed"; if not observable, "merged, deployment unverified". Do not claim user impact you cannot evidence.
- **Blocked** = named blocker + since when + who can unblock. "In progress for 9 days with no commits" counts as blocked; say so.
- **Decisions needed** = the question, the options, and who owns it. This is the most valuable section — lead with it if it's non-empty.
- **Risks to dates** = only where a target date exists and the evidence says it's at risk (open critical, stalled PR, unstarted work inside the window). Name the date.
- No adjectives, no "good progress". Numbers and issue links. If a week was quiet, the status says so in one line rather than padding.

## 3. Format

```
## Week of <date>

**Decisions needed**
- <question> — options A/B — owner: <name> (#N)

**Deployments** (default branch vs what serves users)
- <product> — current (<sha7>, <date>)
- <product> — BEHIND: prod on <sha7>, main +N since <date> / deploy FAILED <date> — <remedy>, owner: <name>
- <product> — not observable; probed <endpoint> → <result>

### <product>
Shipped: <one line, links>
In progress: <one line>
Blocked: <what, since when, who unblocks>
Risk: <date at risk + why>   ← omit the line entirely if none
```
Repeat per product; omit any product with nothing to report except a single "no changes" line. The Deployments block is the one place that never omits a product. End with one line: total merged PRs, total issues closed, open criticals.

## 4. Deliver

Print the status in full, in chat, ready to paste into the team channel. **Do not write it to a file and do not post it anywhere** — this command produces a draft for a human to edit, nothing else.

Then list, separately, anything you noticed but deliberately left out (rules §2: say what this does NOT cover) — e.g. repos you had no access to, a product where the board looked stale enough that the status may be wrong, or a repo where the merged-PR query returned nothing and you could not tell quiet from broken. Two standing items: repos whose default branch is not `main`, and deployment environments whose name misleads (docs' `staging` serves production).
