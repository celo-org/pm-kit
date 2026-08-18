---
description: Draft the weekly per-product status from the board and merged PRs. Usage: /weekly-status [since date, default last Friday]
allowed-tools: Bash(gh *), Bash(jq *), Bash(date *), Read
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

## 2. Rules for what you write

- **Shipped** = merged to `main` in the window. A merged PR is not "shipped to users" unless it was deployed — say which. Do not claim user impact you cannot evidence.
- **Blocked** = named blocker + since when + who can unblock. "In progress for 9 days with no commits" counts as blocked; say so.
- **Decisions needed** = the question, the options, and who owns it. This is the most valuable section — lead with it if it's non-empty.
- **Risks to dates** = only where a target date exists and the evidence says it's at risk (open critical, stalled PR, unstarted work inside the window). Name the date.
- No adjectives, no "good progress". Numbers and issue links. If a week was quiet, the status says so in one line rather than padding.

## 3. Format

```
## Week of <date>

**Decisions needed**
- <question> — options A/B — owner: <name> (#N)

### <product>
Shipped: <one line, links>
In progress: <one line>
Blocked: <what, since when, who unblocks>
Risk: <date at risk + why>   ← omit the line entirely if none
```
Repeat per product; omit any product with nothing to report except a single "no changes" line. End with one line: total merged PRs, total issues closed, open criticals.

## 4. Deliver

Print the status in full, in chat, ready to paste into the team channel. **Do not write it to a file and do not post it anywhere** — this command produces a draft for a human to edit, nothing else.

Then list, separately, anything you noticed but deliberately left out (rules §2: say what this does NOT cover) — e.g. repos you had no access to, a product where the board looked stale enough that the status may be wrong, or a repo where the merged-PR query returned nothing and you could not tell quiet from broken.
