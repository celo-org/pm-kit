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
#   - repo admins may bypass the PR gate in "pull_request" mode: they still open a PR but can merge it
#     without the approval / ci check (emergency hotfix, CI outage). Direct push to main stays blocked.
#
# GITOPS EXCEPTION (per-repo variant only, never the default): a repo whose deploy is a CI job that
# commits back to main (mini-quiz: api-image.yml bumps the Helm image tag, Argo CD deploys from it)
# needs a DEPLOY KEY as an "always" bypass actor (actor_type DeployKey), with the job pushing over
# SSH using that key. GITHUB_TOKEN cannot be granted a bypass (the API rejects the Actions
# integration as an actor), so without this the push is rejected with GH013 and deploys silently
# stall while the image build stays green. Such a repo is
# EXCLUDED from org-ruleset-main.json and governed by its ruleset-main-<repo>.json alone — a bypass
# only works if it is on EVERY ruleset covering the ref, and stacking an org ruleset on top would
# silently re-block the push.
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
  # Repos whose required check differs from "ci / ci", or that need an extra bypass
  # actor (see header), get their own variant file.
  ruleset="ruleset-main.json"
  [ -f "ruleset-main-$(basename "$repo").json" ] && ruleset="ruleset-main-$(basename "$repo").json"
  # Update in place when the ruleset already exists, so re-running this script converges
  # the repo on the checked-in JSON instead of silently leaving a stale ruleset behind.
  # (Lesson: a bypass added to the JSON never reached repos that had been applied earlier.)
  existing=$(gh api "repos/$repo/rulesets" --jq '.[] | select(.source_type=="Repository" and .name=="protect-main") | .id' 2>/dev/null | head -1)
  if [ -n "$existing" ]; then
    gh api "repos/$repo/rulesets/$existing" --method PUT --input "$ruleset" >/dev/null \
      && echo "    updated ruleset 'protect-main' (id $existing) from $ruleset" \
      || echo "    FAILED to update ruleset $existing — need repo admin"
    continue
  fi
  gh api "repos/$repo/rulesets" --method POST --input "$ruleset" >/dev/null \
    && echo "    applied ruleset 'protect-main' ($ruleset)" \
    || echo "    FAILED — check you have admin rights and the plan supports rulesets on this repo (private repos need GitHub Pro/Team)"
done
