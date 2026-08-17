---
description: Close a PR without merging while capturing what it proved. Usage: /close-pr <PR number> <one-line reason>
allowed-tools: Bash(gh *), Bash(git *), Read
---

PR to close: $ARGUMENTS

Follow `.claude/shared/engineering-rules.md` §6 ("Closing a PR without merging"). Unmerged work often contains proven pieces.

1. `gh pr view <N> --json title,body,headRefOid,headRefName,files,closingIssuesReferences,comments`. Read the diff and the discussion.
2. Identify what is reusable — not just files, but what the PR *proved*: a working flow, a validated threshold, a reproduced bug, a negative result (record *why* it failed precisely — "doesn't work" vs "applied wrong").
3. Find the issue that carries the work forward (`closingIssuesReferences`, or search). If none exists and there is remaining work, draft one (`/file-issue` shape).
4. Draft a comment for that issue capturing the reusable pieces, with file links **pinned to the PR's head SHA** (`https://github.com/OWNER/REPO/blob/<headRefOid>/path#L10-L20`), never to the branch.
5. Draft the PR closing comment: why it's closing, where the value went (link), thanks if it's a contributor's PR, invitation for fresh work. Do NOT delete the branch unless there's a reason.
6. Show me both drafts. **Do not post or close until I confirm.**
