---
description: After a PR merges, verify what actually closed and whether it should have. Usage: /post-merge <PR number>
allowed-tools: Bash(gh *)
---

A PR just merged: #$ARGUMENTS. Do the post-merge check.

1. Get the PR: `gh pr view $ARGUMENTS --json title,body,mergedAt,mergedBy,closingIssuesReferences`.
2. From the body, list every `Closes #N` and every `Refs #N`.
3. `closingIssuesReferences` is what GitHub *actually* linked (body keywords + Development-sidebar links). Compare it with the body:
   - Any issue in `closingIssuesReferences` that the body only says `Refs` for, or doesn't mention → **it closed by sidebar link, probably unintended.**
4. For each issue that closed (`gh issue view N --json title,state,closedAt,body`):
   - Re-read its acceptance criteria / definition of done.
   - Judge from the PR diff summary whether they are met. Be strict — "related progress" is not "done".
5. Report a table: issue · how it closed (keyword / sidebar) · criteria met? (yes / partial / no) · recommended action.
6. For any *partial* or *no*: draft the reopen comment and, if closing orphaned remaining work, draft the successor issue (title, body following `.github/ISSUE_TEMPLATE/`, `Refs #N`). Show me the drafts. **Do not reopen or create anything until I confirm.**
