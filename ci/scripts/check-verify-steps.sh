#!/usr/bin/env bash
# Every control ("### N.") must have exactly one "- **Verify:**" step. Counted per control,
# since file totals let a missing step and a doubled one cancel out. A control ends at the
# next control or "#"/"##" heading; fenced code is skipped first so its "# comments" don't.
set -euo pipefail
cd "$(dirname "$0")/../.."

status=0
for f in skills/*/SKILL.md; do
  echo "$(basename "$(dirname "$f")"): controls=$(grep -cE '^### [0-9]+\.' "$f") verify=$(grep -cE '^[[:space:]]*- \*\*Verify:\*\*' "$f")"
  awk 'function done() { if (id != "" && n != 1) { print FILENAME ": control " id " has " n " Verify: steps"; bad = 1 }
                         id = "" }
       /^[ \t]*(```|~~~)/ { fenced = !fenced; next }
       fenced             { next }
       /^### [0-9]+\./    { done(); id = $2; sub(/\.$/, "", id); n = 0; next }
       /^##? /            { done(); next }
       id != "" && /^[ \t]*- \*\*Verify:\*\*/ { n++ }
       END                { done(); exit bad }' "$f" || status=1
done
exit $status
