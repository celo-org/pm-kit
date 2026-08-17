#!/usr/bin/env bash
# Create the canonical label set. Usage: ./create-labels.sh owner/repo [owner/repo ...]
# Agents are told to never invent labels — so these must exist.
set -euo pipefail
for repo in "$@"; do
  echo "==> $repo"
  for l in "bug|d73a4a|Something is broken" \
           "enhancement|a2eeef|User story / feature" \
           "chore|cfd3d7|Refactor, deps, infra, docs" \
           "priority:critical|b60205|Money correctness, security, or user-visible wrong data" \
           "priority:high|fbca04|Major feature broken, workaround exists" \
           "priority:medium|c2e0c6|" \
           "priority:low|ededed|Minor / cosmetic" \
           "status: triage|ededed|Needs triage"; do
    IFS='|' read -r name color desc <<< "$l"
    gh label create "$name" --color "$color" --description "$desc" --force -R "$repo" >/dev/null && echo "    $name"
  done
done
