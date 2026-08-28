#!/usr/bin/env bash
# Test the appsec-protocols semgrep ruleset against its fixtures.
#
# Two assertions, both of which have caught real bugs:
#   1. every rule fires on vulnerable/  -- a rule that never fires is not a control
#   2. no rule fires on safe/           -- a rule that always fires gets disabled by whoever
#                                          has to merge, which is the same as not existing
#
# Run: ci/scripts/test-semgrep-rules.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RULES="$ROOT/ci/semgrep/appsec-protocols.yml"
FIXTURES="$ROOT/ci/semgrep/fixtures"

command -v semgrep >/dev/null || { echo "semgrep not installed: pip install semgrep"; exit 127; }

[ -d "$FIXTURES/vulnerable" ] || { echo "missing $FIXTURES/vulnerable"; exit 1; }

# Fixtures are copied outside the repository before scanning. Two separate ignore
# mechanisms would otherwise silence them, and both did during development:
#   - semgrep's DEFAULT ignore list skips any path containing 'tests' (hence fixtures/)
#   - this repo's .semgrepignore excludes ci/semgrep/fixtures/ so the fixtures are not
#     scanned as application source, and --include is applied AFTER that filter, so it
#     cannot bring them back
# Scanning a copy in a clean directory is immune to both.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -R "$FIXTURES/vulnerable" "$WORK/vulnerable"
cp -R "$FIXTURES/safe" "$WORK/safe"

scan() {
  semgrep --config "$RULES" --json --quiet --no-git-ignore --metrics=off "$1" 2>/dev/null
}

echo "== rules must fire on vulnerable fixtures =="
expected=$(grep -E '^  - id:' "$RULES" | sed 's/  - id: //' | sort)
fired=$(scan "$WORK/vulnerable" | python3 -c "
import json,sys
print('\n'.join(sorted({r['check_id'].split('.')[-1] for r in json.load(sys.stdin)['results']})))
")
silent=$(comm -23 <(echo "$expected") <(echo "$fired"))

if [ -n "$silent" ]; then
  echo "FAIL — these rules matched nothing in vulnerable/:"
  echo "$silent" | sed 's/^/    /'
  echo "  A rule with no fixture proving it fires is an untested check. Add a fixture or fix the rule."
  exit 1
fi
echo "PASS — all $(echo "$expected" | wc -l | tr -d ' ') rules fired"

echo
echo "== no rule may fire on safe fixtures =="
noise=$(scan "$WORK/safe" | python3 -c "
import json,sys
for r in json.load(sys.stdin)['results']:
    print(f\"    {r['check_id'].split('.')[-1]}  {r['path']}:{r['start']['line']}\")
")
if [ -n "$noise" ]; then
  echo "FAIL — false positives on correct code:"
  echo "$noise"
  echo "  A gate that flags correct code gets switched off. Narrow the rule."
  exit 1
fi
echo "PASS — zero findings on safe fixtures"

echo
echo "ruleset OK"
