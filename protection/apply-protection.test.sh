#!/usr/bin/env bash
# Tests for apply-protection.sh, run by .github/workflows/protection-tests.yml.
#
# The trap this exists for: most of our repos are covered by the org-level ruleset and are
# applied with SKIP_REPO_RULESET=1, which takes an early `continue`. Any step written below
# that line silently skips the majority of the roster — and skips it without failing, which
# is the same shape as the bug in #28 itself (a security gap that emits no signal).
#
# `gh` is stubbed with a script on PATH that records its arguments, so these assert on the
# API calls the script actually makes rather than on the text it prints.

set -uo pipefail
cd "$(dirname "$0")" || exit 1

SCRIPT="$PWD/apply-protection.sh"
failures=0

pass() { echo "  ok   — $1"; }
fail() { echo "  FAIL — $1"; failures=$((failures + 1)); }

# assert <expected: found|absent> <grep pattern> <ok message> <failure message>
assert() {
  local want="$1" pattern="$2" ok="$3" bad="$4"
  if grep -q -- "$pattern" "$CALLS"; then
    if [ "$want" = "found" ]; then pass "$ok"; else fail "$bad"; fi
  else
    if [ "$want" = "absent" ]; then pass "$ok"; else fail "$bad"; fi
  fi
}

# Stub `gh` into a temp dir at the front of PATH. It logs one line per invocation and
# succeeds, so the script under test runs its full path without touching the network.
setup_stub() {
  STUB_DIR=$(mktemp -d)
  CALLS="$STUB_DIR/calls.log"
  : >"$CALLS"
  cat >"$STUB_DIR/gh" <<STUB
#!/usr/bin/env bash
echo "\$*" >>"$CALLS"
# 'gh api repos/x/rulesets --jq ...' is read for an existing ruleset id; empty means "none",
# which sends the script down the create path. That is the branch we want under test.
exit 0
STUB
  chmod +x "$STUB_DIR/gh"
  export PATH="$STUB_DIR:$PATH"
}

teardown_stub() {
  PATH="${PATH#"$STUB_DIR":}"
  rm -rf "$STUB_DIR"
}

# ---------------------------------------------------------------------------
# The regression: security settings must be converged for a repo whose ruleset
# is skipped, because that is how nearly every repo in the roster is applied.
# ---------------------------------------------------------------------------
echo "SKIP_REPO_RULESET=1 (how most of the roster is applied)"
setup_stub
SKIP_REPO_RULESET=1 "$SCRIPT" celo-org/fixture-repo >/dev/null 2>&1

assert found "repos/celo-org/fixture-repo/vulnerability-alerts --method PUT" \
  "enables Dependabot alerts" \
  "no PUT to vulnerability-alerts — the security step is below the early continue"

assert found "repos/celo-org/fixture-repo/automated-security-fixes --method PUT" \
  "enables Dependabot security updates" \
  "no PUT to automated-security-fixes — the security step is below the early continue"

assert found "repos/celo-org/fixture-repo --method PATCH" \
  "still applies merge settings" \
  "merge settings were not applied"

# The control. If this passed too, the fixture would prove nothing about ordering —
# every assertion above would hold for a script that ignored SKIP_REPO_RULESET entirely.
assert absent "rulesets --method POST" \
  "skips the repo ruleset, as asked" \
  "created a repo ruleset despite SKIP_REPO_RULESET=1"
teardown_stub

# ---------------------------------------------------------------------------
# The default path still does everything.
# ---------------------------------------------------------------------------
echo "SKIP_REPO_RULESET unset"
setup_stub
"$SCRIPT" celo-org/fixture-repo >/dev/null 2>&1

assert found "repos/celo-org/fixture-repo/vulnerability-alerts --method PUT" \
  "enables Dependabot alerts" \
  "no PUT to vulnerability-alerts"

assert found "repos/celo-org/fixture-repo/automated-security-fixes --method PUT" \
  "enables Dependabot security updates" \
  "no PUT to automated-security-fixes"

assert found "rulesets --method POST" \
  "applies the repo ruleset" \
  "the repo ruleset was not applied"
teardown_stub

# ---------------------------------------------------------------------------
# Every repo named on the command line gets the settings, not just the first.
# ---------------------------------------------------------------------------
echo "multiple repos"
setup_stub
SKIP_REPO_RULESET=1 "$SCRIPT" celo-org/one celo-org/two >/dev/null 2>&1

count=$(grep -c "automated-security-fixes --method PUT" "$CALLS")
if [ "$count" = "2" ]; then
  pass "both repos got the security settings"
else
  fail "expected 2 PUTs to automated-security-fixes, got $count"
fi
teardown_stub

echo
if [ "$failures" -ne 0 ]; then
  echo "$failures failing assertion(s)"
  exit 1
fi
echo "all assertions passed"
