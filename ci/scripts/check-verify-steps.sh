#!/usr/bin/env bash
# Every control (a "### N." heading) must carry exactly one "Verify:" step.
#
# Comparing file-wide totals is not enough: a control with none and a control with two
# cancel out, and both counts still read 44.
set -euo pipefail
cd "$(dirname "$0")/../.."

status=0
for f in skills/*/SKILL.md; do
  echo "$(basename "$(dirname "$f")"): controls=$(grep -cE '^### [0-9]+\.' "$f") verify=$(grep -c 'Verify:' "$f")"
  awk '/^### [0-9]+\./ { if (id && n != 1) { print FILENAME ": control " id " has " n " Verify: steps"; bad = 1 }
                         id = $2; sub(/\.$/, "", id); n = 0; next }
       { n += gsub(/Verify:/, "") }
       END { if (id && n != 1) { print FILENAME ": control " id " has " n " Verify: steps"; bad = 1 }
             exit bad }' "$f" || status=1
done
exit $status
