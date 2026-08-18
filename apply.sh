#!/usr/bin/env bash
# One-time bootstrap of a repo onto pm-kit. Run from the REPO ROOT:
#   bash /path/to/pm-kit/apply.sh
#
# After this, updates flow automatically:
#   - CI steps: the caller points at celo-org/pm-kit@main — edit pm-kit, every repo picks it up
#   - Templates + shared rules: pm-kit's sync workflow opens PRs into each repo
#   - Commands: `claude plugin update pm-kit`
# The only repo-owned files are CLAUDE.md and the thin CI caller (with its inputs).
# Never overwrites existing files.

set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
OWNER="${PM_KIT_OWNER:-celo-org}"   # override only if pm-kit lives elsewhere

copy_if_absent() { if [ -e "$2" ]; then echo "  skip (exists): $2"; else mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "  added: $2"; fi; }

# ---- Detect stack + package manager ----
stack="node"
if [ -f foundry.toml ]; then stack="foundry"
elif ls hardhat.config.* >/dev/null 2>&1; then stack="hardhat"
elif [ -f docs.json ] && [ ! -f package.json ]; then stack="mintlify"
elif [ -f package.json ]; then stack="node"
elif [ -f pyproject.toml ] || [ -f requirements.txt ]; then stack="python"
else stack="unknown"; fi
pm="npm"; [ -f pnpm-lock.yaml ] && pm="pnpm"; [ -f yarn.lock ] && pm="yarn"; { [ -f bun.lock ] || [ -f bun.lockb ]; } && pm="bun"
echo "Detected stack: $stack ($pm)"

# ---- CI caller ----
echo "CI:"
if [ -n "$(ls .github/workflows 2>/dev/null)" ]; then
  echo "  NOTE: existing workflows: $(ls .github/workflows | tr '\n' ' ') — don't duplicate CI. Adding caller only if ci.yml is absent."
fi
case "$stack" in
  node|hardhat|foundry|python) src="$KIT/callers/ci-$stack.yml" ;;
  mintlify) src="$KIT/callers/ci-docs-mintlify.yml" ;;
  *) src="" ;;
esac
if [ -n "$src" ] && [ ! -e .github/workflows/ci.yml ]; then
  mkdir -p .github/workflows
  sed "s#celo-org/pm-kit#$OWNER/pm-kit#g" "$src" > .github/workflows/ci.yml
  echo "  added: .github/workflows/ci.yml (calls $OWNER/pm-kit/.github/workflows/$(basename "$src")@main)"
elif [ -e .github/workflows/ci.yml ]; then echo "  skip (exists): .github/workflows/ci.yml"
else echo "  skipped (unknown stack) — pick a caller from $KIT/callers/"; fi

# ---- Issue-priority labeler (repo-owned, like the CI caller) ----
copy_if_absent "$KIT/callers/issue-priority-label.yml" ".github/workflows/issue-priority-label.yml"

# ---- Templates + shared rules (kept in sync afterwards by pm-kit's sync workflow) ----
echo "Templates & shared rules:"
for f in "$KIT"/templates/.github/ISSUE_TEMPLATE/*.yml; do copy_if_absent "$f" ".github/ISSUE_TEMPLATE/$(basename "$f")"; done
copy_if_absent "$KIT/templates/.github/PULL_REQUEST_TEMPLATE.md" ".github/PULL_REQUEST_TEMPLATE.md"
copy_if_absent "$KIT/templates/.claude/shared/engineering-rules.md" ".claude/shared/engineering-rules.md"
copy_if_absent "$KIT/templates/.claude/shared/money-path-checklist.md" ".claude/shared/money-path-checklist.md"
copy_if_absent "$KIT/templates/.claude/shared/tester-mode-pattern.md" ".claude/shared/tester-mode-pattern.md"
if [ ! -f renovate.json ] && [ ! -f .github/renovate.json ]; then copy_if_absent "$KIT/templates/renovate.json" "renovate.json"; else echo "  skip (exists): renovate config"; fi

# ---- CLAUDE.md (repo-owned) ----
echo "CLAUDE.md:"
if [ -f CLAUDE.md ]; then
  echo "  skip (exists): CLAUDE.md — add these two lines to it so shared rules load:"
  echo "      @.claude/shared/engineering-rules.md"
  echo "      @.claude/shared/money-path-checklist.md"
else
  name=$(basename "$(pwd)")
  if [ -f package.json ] && command -v jq >/dev/null; then n=$(jq -r '.name // empty' package.json 2>/dev/null || true); [ -n "$n" ] && name="$n"; fi
  # `|` delimiter: scoped package names (@scope/name) contain `/`
  sed -e "s|{{PROJECT_NAME}}|$name|g" -e "s|{{PM}}|$pm|g" "$KIT/templates/CLAUDE.md.template" > CLAUDE.md
  echo "  added: CLAUDE.md — fill in the {{...}} placeholders (or ask Claude Code to)"
fi

# ---- Vitest scaffold for JS/TS repos without tests ----
if [ "$stack" = "node" ]; then
  if [ -z "$(find . -path ./node_modules -prune -o \( -name '*.test.*' -o -name '*.spec.*' \) -print 2>/dev/null | head -1)" ]; then
    echo "No tests found — Vitest scaffold:"
    copy_if_absent "$KIT/testing/vitest.config.ts" "vitest.config.ts"
    copy_if_absent "$KIT/testing/vitest.setup.ts" "vitest.setup.ts"
    copy_if_absent "$KIT/testing/example.smoke.test.tsx" "src/smoke.test.tsx"
    echo "  then: $pm add -D vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/jest-dom @vitest/coverage-v8"
    echo "  and package.json scripts: \"test\": \"vitest run\", \"lint\": \"eslint .\", \"typecheck\": \"tsc --noEmit\""
  else echo "Tests present — skipping Vitest scaffold."; fi
fi

echo ""
echo "Labels (needs gh): run  bash $KIT/protection/create-labels.sh <owner/repo>"
echo "Plugin: claude plugin marketplace add $OWNER/pm-kit && claude plugin install pm-kit@pm-kit"
echo "Done. Branch, commit, open a PR, watch CI."
