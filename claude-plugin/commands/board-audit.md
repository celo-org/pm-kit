---
description: Audit a backlog at volume — bucket, dedupe, triage, and clean up with confirmation. Usage: /board-audit [repo or "all"] [--resume]
allowed-tools: Bash(gh *), Bash(jq *), Read, Write, Edit, Grep
---

Scope: $ARGUMENTS (a repo like `celo-org/mondeto`, or `all` for every repo on the board; default: the current repo)

Audit the open backlog against `.claude/shared/engineering-rules.md` §1. A board with hundreds of tickets cannot be reviewed one at a time in a chat — so work in **buckets**, propose **batch actions**, and only enumerate individual issues where a judgement call is needed.

## 0. Resume

If `.claude/board-audit.md` exists (or `--resume` was passed), read it and continue from the first bucket whose status is not `done`. Otherwise create it as you go (see §4). This audit will span sessions; the file is the memory.

## 1. Pull the data (bucket on light fields; fetch bodies only where you must)

**Never pull `body` or `comments` for the whole backlog** — on a board of several hundred issues that exhausts the context window before bucketing starts. Two passes:

**Pass 1 — totals.** One call, summarised in `jq`, nothing per-issue in context:
```
gh issue list --state open --limit 1000 \
  --json number,title,labels,assignees,createdAt,updatedAt,url \
  | jq '{
      total: length,
      no_priority: [.[] | select([.labels[].name] | any(startswith("priority:")) | not)] | length,
      no_size:     [.[] | select([.labels[].name] | any(startswith("size:"))     | not)] | length,
      unassigned:  [.[] | select(.assignees | length == 0)] | length,
      age_lt30:  [.[] | select((now-(.updatedAt|fromdate))/86400 <  30)] | length,
      age_30_90: [.[] | select((now-(.updatedAt|fromdate))/86400 >= 30 and (now-(.updatedAt|fromdate))/86400 <= 90)] | length,
      age_gt90:  [.[] | select((now-(.updatedAt|fromdate))/86400 >  90)] | length }'
```
Age here is **time since last activity** (`updatedAt`), because that is what bucket A tests — say so when you report it, so nobody reads it as time since filing. If `total` comes back as exactly 1000 the list was truncated: **say so** rather than reporting partial totals as complete.

**Pass 2 — one line per issue** for the bucketing itself:
```
gh issue list --state open --limit 1000 \
  --json number,title,labels,assignees,createdAt,updatedAt,url \
  | jq -r '.[] | [.number,
                  ((now-(.updatedAt|fromdate))/86400|floor),
                  ((now-(.createdAt|fromdate))/86400|floor),
                  ([.labels[].name]|join(",")),
                  (.assignees|length),
                  .title] | @tsv'
```

**Open PRs**, same treatment:
```
gh pr list --state open --limit 200 \
  --json number,title,isDraft,reviewDecision,createdAt,updatedAt,author,url \
  | jq -r '.[] | [.number,
                  ((now-(.updatedAt|fromdate))/86400|floor),
                  (.isDraft|tostring),
                  (.reviewDecision | if . == null or . == "" then "NONE" else . end),
                  .author.login,
                  .title] | @tsv'
```

**Board fields**, if the repo is on a project: `gh project item-list <number> --owner <org> --format json --limit 1000`, projected through `jq` to `item-id · content number · Status · Product · Priority`. This is also how you find issues that are **not** on the board at all.

For `all`, repeat per repo (or `gh search issues --owner celo-org --state open --limit 1000 --json number,title,labels,assignees,createdAt,updatedAt,url,repository`).

Report the totals table first — open issues per repo, per label, per age bucket, and how many have no priority. That table is the audit's starting evidence. Use no shell redirection (`>`); pipe through `jq` so each command stays inside the allow-list.

## 2. Bucket mechanically (no judgement yet)

Sort every open item into exactly one bucket, most-mechanical first:

| Bucket | Test | Proposed batch action |
|---|---|---|
| **A. Stale** | no activity >90d AND not `priority:critical` | close with evidence, or relabel `status: triage` if still real |
| **B. Missing metadata** | any of: no `priority:*`, no type label, no `size:*`, no assignee, not on the board (rules §1 requires all five at filing) | needs a decision — enumerate (§3), naming which are missing |
| **C. Likely duplicates** | high title/body similarity, or same file-set implied | merge candidates — enumerate (§3) |
| **D. Same-diff clusters** | different issues one diff would close (rules §1 "same-diff test") | merge into one ticket with a checklist |
| **E. Sprawling** | >1 fix-unit, or mixes a live defect with hardening (different-schedule test) | split into lettered children A–G with a status table on the parent |
| **F. No acceptance criteria** | user story / feature with no testable checklist | rewrite needed — flag for the owner |
| **G. Healthy** | one fix-unit, priority set, criteria testable | leave alone; count only |
| **H. Stale PRs** | open >30d with no new commits and no review | close via the `/close-pr` shape (capture what it proved), or mark ready for review |

Print bucket counts. **Do not act yet.**

## 3. Enumerate only what needs judgement

For buckets B–F and H, list the items compactly — one line each: `#N · title · why it's in this bucket · proposed action`. Cap at 25 per message; if a bucket is larger, do it in pages and record progress in `.claude/board-audit.md`.

Verify before proposing: this is where you spend the body fetch — `gh issue view N --json body,comments` for the ≤25 items on the current page only, never for the whole bucket. Read the body, not just the title, for anything you'd close or merge. A duplicate that isn't one costs more than a duplicate left standing. For anything touching money, security, or a live defect, propose `keep` unless you are certain.

## 4. Write the plan to `.claude/board-audit.md`

```
| Bucket | Count | Decision | Status |
|---|---|---|---|
| A. Stale | 34 | close with evidence | pending |
```
Plus a per-issue table for B–F and H with `#N | action | status`. Statuses: `pending` → `approved` → `done`. This is what makes the audit resumable and reviewable.

## 5. Apply — only after I confirm, bucket by bucket

Confirm one bucket at a time; never all at once. Then:
- **Close** with evidence, never "done": `gh issue close N --comment "Closing: <what was verified / superseded by #M / no longer reproduces on <version>>. Reopen if it still happens."`
- **Label**: existing labels only (`bug` `enhancement` `chore` `priority:critical|high|medium|low` `size:S|M|L` `status: triage`). Never invent a label; if none fits, say so.
- **Assign**: default to the person most recently active in the code the issue touches (rules §1). If you can't tell, propose no assignee rather than guessing.
- **Merge duplicates**: comment on the survivor listing what it absorbs, then close the others pointing at it. Move any unique content across first.
- **Split sprawl**: draft the children (`/file-issue` shape) and a status table on the parent; create only after I approve the drafts.
- **PRs**: retitle, relabel, or convert draft↔ready in batch; **closing** a PR goes through the `/close-pr` procedure so the work it proved is captured before it disappears.
- **Board fields**: resolve IDs once with `gh project field-list <number> --owner <org> --format json` and the item IDs from §1, then set Product / Priority / Status via `gh project item-edit --id <item> --field-id <field> --project-id <project>`. Add missing issues with `gh project item-add`.
- **Deletion is not a batch action.** `gh issue delete` is irreversible and admin-only. Default to closing with evidence — a closed issue stays searchable and keeps its thread. Delete only for spam or an issue filed by accident, one at a time, confirmed individually, never inside an approved bucket.

After each bucket, update the statuses in `.claude/board-audit.md` and report what changed. Stop and ask if any single action would close something labelled `priority:critical`.

## 6. Report

End with: totals before/after, the three biggest risks you noticed in the backlog (not tickets — patterns: e.g. "no acceptance criteria on 60% of stories", "two products have no critical-path tickets at all"), and what remains `pending`.
