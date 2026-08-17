#!/usr/bin/env bash
# ORG-LEVEL alternative to apply-protection.sh: one ruleset on celo-org targeting our repos by name.
# Needs org admin (or "custom repository role" with ruleset permission) + GitHub Team/Enterprise (celo-org has it).
# Repo merge settings (squash-only, title=PR title, auto-merge) are still per-repo — apply-protection.sh
# does those; run it too, or just use apply-protection.sh alone if you lack org admin.
set -euo pipefail
cd "$(dirname "$0")"
ORG="${1:-celo-org}"
if gh api "orgs/$ORG/rulesets" --jq '.[].name' 2>/dev/null | grep -qx "pm-kit-protect-main"; then
  id=$(gh api "orgs/$ORG/rulesets" --jq '.[] | select(.name=="pm-kit-protect-main") | .id')
  gh api "orgs/$ORG/rulesets/$id" --method PUT --input org-ruleset-main.json >/dev/null && echo "updated org ruleset pm-kit-protect-main (id $id)"
else
  gh api "orgs/$ORG/rulesets" --method POST --input org-ruleset-main.json >/dev/null && echo "created org ruleset pm-kit-protect-main"
fi
echo "Targets: $(python3 -c "import json;print(', '.join(json.load(open('org-ruleset-main.json'))['conditions']['repository_name']['include']))")"
echo "Add a repo later: edit org-ruleset-main.json repository_name.include and re-run."
