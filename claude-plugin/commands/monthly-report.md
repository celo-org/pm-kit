---
description: Draft the monthly ambassador/programme report from the board, merged PRs and deployments. Usage: /monthly-report [YYYY-MM, default last full month]
allowed-tools: Bash(gh *), Bash(jq *), Bash(date *), Read
---

Month: $ARGUMENTS (default: the last full calendar month)

Follow `.claude/shared/engineering-rules.md` §1 for the evidence bar — every line here is something you ran, not something you inferred.

This is the monthly counterpart to `/weekly-status`. It is longer, it is read by one person rather than a channel, and it is read **next to other people's reports for the same month**. You draft, a human edits — do not post it and do not share it anywhere.

## 0. Read last month's report BEFORE writing this one

Open the previous month's report and list its headings. **Nothing else in this workflow compares a new report against the last one**, which is exactly how a heading gets renamed or dropped without anyone deciding to.

- **Keep the headings stable month to month, even when the work has moved.** They are how a reader scans several reports side by side.
- If a section no longer applies, **keep the heading and say so underneath it**. Writing *"no numbered targets were set for this period"* under a KPI heading is strictly stronger than deleting the heading: it answers the question the heading raises instead of removing the question. A missing section reads as a hidden number.
- Reordering is allowed where the mandate has genuinely shifted — lead with the biggest body of work — but rename nothing.

## 1. Gather (evidence, not impressions)

Per repo in scope, bounded to the month:
```
gh pr list --state merged --search "merged:YYYY-MM-01..YYYY-MM-31" --json number,title,mergedAt,url
gh issue list --state closed --search "closed:YYYY-MM-01..YYYY-MM-31" --json number,title,url
gh issue list --state open --label "priority:critical" --json number,title,url,updatedAt
gh api "/search/issues?q=is:pr+author:<you>+created:YYYY-MM-01..YYYY-MM-31" --jq .total_count
```
Counts that describe your own contribution — PRs opened, commits, issues filed, reviews given — belong in the report. Take them from the API, never from memory, and name the query you ran.

## 2. Rules for what you write

- **Merged is not shipped.** A PR merged to `main` is not in front of users until it is deployed. Check the deployment — a build timestamp, a version endpoint, the live page — and say which state each item is in. *"Merged 14 Aug, deployed 2 Sep"* and *"merged, not yet deployed"* are both fine; *"shipped"* for something still sitting on `main` is not.
- **Blocked** = named blocker + since when + who can unblock. Work that has been "in progress" for weeks with no commits is blocked; say so.
- **Decisions needed** = the question, the options, and who owns it. If this section is non-empty it goes **first**, before the narrative. It is the only part that changes what happens next.
- **Numbers you did not measure do not go in.** Costs, user counts, timelines, revenue: cite the query or the source, or label it an estimate. An unattributed number is the one thing a reader cannot check and will remember.
- **No adjectives.** "Significant progress", "successfully delivered", "strong momentum" — cut all of it. Numbers and links.
- **Do not publish a claim about a third party that they do not publish themselves.** If an integration was mentioned to you privately, ask for the public endpoint before it goes in a report.
- **One outcome per bullet, with its link.** Outside GitHub a bare `#123` is dead text and does not even say which repo — write the number as the label and put the URL under it.

## 3. What the report is not

- Not a task log. Nobody needs the list of everything you touched; they need what changed and what is now different.
- Not a target table if no targets were agreed. Reconstructing one invites being measured against numbers nobody set.
- Not the place for the honest self-review. Keep that separate and private; a report that mixes the two does neither job.

## 4. Deliver

Print the draft in full, in chat. Then, separately, list:

- **what this does NOT cover** — repos you had no access to, a count you could not run, a deployment you could not confirm;
- **anything you left out deliberately**, and why.

Finally, two reminders for the human who sends it:

- **Share it as a link, not a file.** A downloadable copy cannot be updated after a correction.
- **A shared document is a channel, not a drop-off.** Reviewers answer *inside the document as comments*, and those notify nowhere. Check the comments on anything shared this way, and treat a CC'd name as routing rather than decoration.

## 5. The obligation has no ticket

A monthly report, unlike a deliverable, exists on no board — so a deadline sweep over issues finds nothing and reports "nothing outstanding" the week it is due. If this command is part of a recurring obligation, record the obligation somewhere the sweep will read, not only in someone's memory.
