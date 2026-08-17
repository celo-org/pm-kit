---
description: File a GitHub issue that meets the playbook bar (verified claims, file:line, impact, evidence). Usage: /file-issue <one-line description of the problem>
allowed-tools: Bash(gh *), Bash(git *), Read, Grep, Glob
---

Problem to file: $ARGUMENTS

Follow `.claude/shared/engineering-rules.md` §1 (Issues). Concretely:

1. **Verify before filing.** Reproduce it: run the command, read the code path, check the fact at its source (chain via eth_call, package API in node_modules, advisory API). Distinguish "I ran this and here is the output" from "static reading suggests". If you cannot verify, say so explicitly in the issue — never present a reading as a run.
2. **Name the defect where users are served.** If found in a fallback/dev-only path, check whether the production path has the same defect and state which.
3. **Cluster by fix boundary.** Before filing, check `gh issue list --search "<keywords>"` for an existing home. If this and an existing issue would be closed by the same diff, add a comment there instead of filing. If this is several independently fixable, schedulable problems, file several issues (one priority each), not one.
4. **Body anatomy** (use the matching form in `.github/ISSUE_TEMPLATE/` — bug_report / user_story / task):
   - What happens: exact commands + real output (or user steps + observed result)
   - Root cause: `file:line`, if known
   - Impact: who hits this, doing what; for security/money, what the attacker gets
   - Suggested fix (and what it does NOT fix)
   - Non-goals / dependencies / ordering
   - Acceptance criteria as checkboxes — testable; code work and ops work as separate boxes
   - How we'd know it's fixed (metric/log/check), and version/commit tested
   - Open questions marked OPEN ("number left to implementer") so the implementer surfaces the call instead of guessing
   - Prior art / related code linked at a commit SHA, never a branch
   - Measurements where they exist ("225 of 574 responses were template output") — they become pinned tests
5. Labels: existing labels only (`bug`/`enhancement`/`chore`, one `priority:*`, `status: triage`). Never invent labels. `priority:critical` = money correctness, security, or user-visible wrong data.
6. Show me the full title + body + labels. **Do not create the issue until I confirm.** After creation, add it to the project board if the repo has one (`gh project item-add`).
