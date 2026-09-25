#!/usr/bin/env bash
# Every control (a "### N." heading) must carry exactly one "Verify:" step.
#
# Comparing file-wide totals is not enough: a control with none and a control with two
# cancel out, and both counts still read 44.
#
# A control's scope ends at the next control, the next group or section heading (# or ##),
# or end of file. Without that, a "Verify:" in a group intro or a trailing section would be
# credited to the control above it and could hide a missing step.
set -euo pipefail
cd "$(dirname "$0")/../.."

status=0
for f in skills/*/SKILL.md; do
  echo "$(basename "$(dirname "$f")"): controls=$(grep -cE '^### [0-9]+\.' "$f") verify=$(grep -c 'Verify:' "$f")"
  awk 'function done() { if (id != "" && n != 1) { print FILENAME ": control " id " has " n " Verify: steps"; bad = 1 }
                         id = "" }
       /^### [0-9]+\./ { done(); id = $2; sub(/\.$/, "", id); n = 0; next }
       /^##? /         { done(); next }
       id != ""        { n += gsub(/Verify:/, "") }
       END             { done(); exit bad }' "$f" || status=1
done
exit $status
