---
description: Implement an issue the way a senior engineer would. It sharpens the spec first, reproduces the before-state, writes the failing test, then fixes, simplifies, and verifies every scenario. Usage: /start-issue <issue number>
allowed-tools: Bash(gh issue view *), Bash(gh issue list *), Bash(git *), Bash(pnpm *), Bash(npm *), Bash(yarn *), Bash(bun *), Bash(node *), Bash(curl *), Read, Grep, Glob, Edit, Write, mcp__plugin_pm-kit_playwright
---

Issue: #$ARGUMENTS

Follow `.claude/shared/engineering-rules.md` §1–3. Read the repo's `CLAUDE.md` and, if it exists, `.claude/verify.md` before anything else.

The order below is the point of this command. Every **STOP** means: show me what you have and wait for my answer. Do not carry on past it on your own guess.

## 1. Read the ticket like a reviewer would

`gh issue view $ARGUMENTS --json title,body,labels,comments`. Read the comments too: scope often changes there.

A ticket is ready to build when it has all three of these:
- **Task**: what should be true afterwards, in one or two sentences.
- **Context**: the files or modules involved (`file:line` where known), related issues and PRs, the docs or designs to follow, and the constraints (stack, things that must not change).
- **Verification scenarios**: concrete checks that prove it is done, including the edge cases. For example: "given an empty cart, when I pay, then I see …". The acceptance boxes count if they are this concrete.

Find the answers yourself first: grep the code, read the linked PRs, check `git log` on the files involved. Only ask about what the code cannot tell you.

## 2. Interrogate the spec, then STOP

List the questions you still have, at most five, the sharpest first. Aim for things that would change the code:
- **Edge cases**: empty, zero, max, Unicode, concurrent, a double submit, a network failure halfway through.
- **Hidden assumptions**: which user, which environment, which chain or token, what happens to existing data.
- **Scope**: what is deliberately out of scope, and whether there is anything nearby you should not touch.
- **Done**: what you would show me to prove it works.

For each question, give your proposed answer, so I can reply "yes" instead of writing an essay.

If the ticket is missing a whole section (no verification scenarios, no context), draft that section for me.

**STOP.** After I answer, propose the answers as a comment on the issue, so the next person does not ask again. Post it only when I confirm. Then go on.

## 3. Check the size, and STOP if it is too big

If it is `size:L`, needs more than one PR, or mixes a live bug with a nice-to-have (rules §1, different-schedule test), propose a split into PR-sized slices. Each slice must stand on its own and have its own scenarios. Draft them in the `/file-issue` shape. **STOP**, and build only the slice I pick.

## 4. Prove the before-state

- **Bug:** reproduce it before changing anything, and show the command and its output, or the steps you took and what you saw. Use data shaped like the real case that failed: the same token decimals, the same Unicode name, the same empty list. **Never use production credentials, and never write to production to get it.** If you cannot reproduce it, say so and STOP. A fix for a bug you never saw is a guess.
- **Then trace the root cause** to `file:line`. Do not stop where the error surfaced. Follow it back to where the wrong value was made. Check whether sibling paths (fallback, other route, other chain) have the same defect (rules §1, "Name the defect in the code path that serves users").
- **Feature:** note the current behaviour of the surface you are about to change. That is your before.

## 5. Write the failing test first

Before writing any fix, write the test that encodes the scenario, through the seam it touches (route, CLI or component, not only a pure function; rules §3). Run it and show it **failing for the right reason**: an assertion about the behaviour, not an import error or a typo. A test you never saw fail proves nothing.

## 6. Make it pass with the smallest correct diff

- Reuse before you write. Grep for an existing helper, hook, constant or component that already does this.
- Touch only what the scenarios need. Do not refactor unrelated code, reformat files, or add options nobody asked for.
- Run the full suite, lint and typecheck after the change.

## 7. Simplify before you call it done

Re-read your own diff as if someone else wrote it, and remove:
- dead code, leftover debug logs, and commented-out blocks
- comments that only repeat what the code says (keep comments that explain *why*)
- abstractions with one caller, and config or parameters nothing uses
- anything copied from somewhere that a shared helper could do instead

Run the suite again afterwards.

## 8. Verify every scenario, and show the evidence

Go through the verification scenarios from step 1 one by one. For each one, record what you ran and what you saw:
- **UI:** follow `.claude/verify.md` to start the app and reach the surface. Then do the browser pass from `/write-pr` step 2b, on desktop and phone, with zero console errors and screenshots.
- **Backend or CLI:** `curl` the route or run the command, covering both the accepted path and the rejected one (`/write-pr` step 2a).
- **Mutation check:** revert the fix, see the new test go red, and restore it.

Anything you could not verify gets written down as "not verified", never left out.

If running the app needed a step that `.claude/verify.md` does not describe (a seed script, a test account, an env var, a route), add that step to `verify.md` in this same branch. The next person, or agent, should not have to discover it again.

## 9. Hand off

Summarise: what changed (with `file:line`), every scenario with its evidence, what was not verified, and any judgement calls you made. Then tell me to run `/write-pr $ARGUMENTS`. Do not push or open the PR from this command.
