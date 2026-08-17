#!/usr/bin/env bash
# Apply the main-branch protection ruleset + merge settings to one or more repos.
# Since all repos are in celo-org, prefer apply-org-ruleset.sh for the ruleset (one call, all repos)
# and use THIS script for the per-repo merge settings (those have no org-level equivalent).
# Usage: ./apply-protection.sh owner/repo [owner/repo ...]
# Requires: gh CLI authenticated with admin access to the repos.
#
# What the ruleset enforces (each rule has an incident behind it — see SETUP-GUIDE):
#   - PR required, 1 approval, stale approvals dismissed on push (bot re-rolls invalidate sign-off)
#   - required check "ci" AND branch must be up to date with main (strict) — a green
#     check on a stale head no longer counts; also forces the rebase before merging lockfile PRs
#   - NOT requiring thread resolution (nits must not become soft blockers — rules §9); no force-push; no deletion
#
# CHECK NAME: with the reusable-workflow caller, GitHub names the check "ci / ci"
# (<caller job> / <called job>) — that's what ruleset-main.json requires.
# Repos with their own CI (celo-composer: "test"; celo-org/docs: "Check for broken links")
# need the "context" edited to match, or their job renamed. Confirm the exact name in the
# Checks tab of any PR before applying.

set -euo pipefail
cd "$(dirname "$0")"

if [ $# -eq 0 ]; then
  echo "Usage: $0 owner/repo [owner/repo ...]"
  exit 1
fi

for repo in "$@"; do
  echo "==> $repo"

  # 1) Repo merge settings: squash-only, PR title becomes the commit message.
  #    (Lesson: "merge commits and rebase merges are both still enabled even though
  #     squash is the convention" — make the platform enforce it.)
  gh api "repos/$repo" --method PATCH --silent \
    -F allow_squash_merge=true \
    -F allow_merge_commit=false \
    -F allow_rebase_merge=false \
    -F delete_branch_on_merge=true \
    -F allow_auto_merge=true \
    -f squash_merge_commit_title=PR_TITLE \
    -f squash_merge_commit_message=PR_BODY \
    && echo "    merge settings: squash-only, title=PR title, body=PR body, auto-delete branches" \
    || echo "    WARN: could not update merge settings (need admin)"

  # 2) Branch ruleset (skip when the org-level ruleset already covers this repo)
  if [ "${SKIP_REPO_RULESET:-0}" = "1" ]; then echo "    ruleset: skipped (org ruleset covers it)"; continue; fi
  if gh api "repos/$repo/rulesets" --jq '.[].name' 2>/dev/null | grep -qx "protect-main"; then
    echo "    ruleset 'protect-main' already exists — skipping (edit it in Settings > Rules)"
    continue
  fi
  gh api "repos/$repo/rulesets" --method POST --input ruleset-main.json >/dev/null \
    && echo "    applied ruleset 'protect-main'" \
    || echo "    FAILED — check you have admin rights and the plan supports rulesets on this repo (private repos need GitHub Pro/Team)"
done
