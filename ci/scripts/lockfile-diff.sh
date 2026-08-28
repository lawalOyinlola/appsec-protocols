#!/usr/bin/env bash
# Control 23 — vet the package itself, not just its CVEs.
#
# A vulnerability scanner reads a database of known flaws in real packages. It says nothing
# about a package that is malicious by design and three days old. This script answers the
# different question: what did this PR ADD to the dependency tree, and does any of it look
# like a typosquat or a brand-new package nobody has vetted?
#
# It does not decide. It produces the list a human has to account for, and fails the build
# when something crosses a threshold that warrants a look.
#
# Usage:  ci/scripts/lockfile-diff.sh [BASE_REF] [HEAD_REF]
#         BASE_REF defaults to origin/main, HEAD_REF to the working tree.
set -uo pipefail

BASE="${1:-origin/main}"
HEAD_REF="${2:-}"
MIN_AGE_DAYS="${MIN_AGE_DAYS:-30}"
MIN_DOWNLOADS="${MIN_DOWNLOADS:-1000}"
REGISTRY="https://registry.npmjs.org"
API="https://api.npmjs.org/downloads/point/last-week"

LOCKFILES=(package-lock.json npm-shrinkwrap.json pnpm-lock.yaml yarn.lock)

command -v python3 >/dev/null || { echo "python3 required"; exit 127; }

lock=""
for f in "${LOCKFILES[@]}"; do
  [ -f "$f" ] && { lock="$f"; break; }
done
if [ -z "$lock" ]; then
  echo "no lockfile found (looked for: ${LOCKFILES[*]})"
  echo "Control 23 also requires that a lockfile is COMMITTED and installs run from it"
  echo "(npm ci, not npm install). A repo with no lockfile fails this control."
  exit 1
fi
echo "lockfile: $lock"

if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  echo "base ref '$BASE' not found; nothing to diff against. Treating as first commit."
  exit 0
fi

before=$(mktemp); after=$(mktemp)
trap 'rm -f "$before" "$after"' EXIT
git show "$BASE:$lock" > "$before" 2>/dev/null || echo "" > "$before"
if [ -n "$HEAD_REF" ]; then
  git show "$HEAD_REF:$lock" > "$after" 2>/dev/null || cp "$lock" "$after"
else
  cp "$lock" "$after"
fi

# Extract package names from either lockfile format. package-lock v2/v3 keys are paths
# like "node_modules/foo" and "node_modules/a/node_modules/b" -- the last segment is the name.
added=$(python3 - "$before" "$after" "$lock" <<'PY'
import json, re, sys

before_p, after_p, kind = sys.argv[1], sys.argv[2], sys.argv[3]


def names(path):
    try:
        text = open(path).read()
    except OSError:
        return set()
    if not text.strip():
        return set()
    out = set()
    if kind.endswith(".json"):
        try:
            d = json.loads(text)
        except json.JSONDecodeError:
            return set()
        for key in d.get("packages", {}):
            if not key:
                continue
            out.add(key.split("node_modules/")[-1])
        for key in d.get("dependencies", {}):
            out.add(key)
    else:
        # pnpm-lock.yaml / yarn.lock: entries look like /name/version or "name@range:"
        for m in re.finditer(r"^\s{0,4}[\"']?/?((?:@[\w.-]+/)?[\w.-]+)@", text, re.M):
            out.add(m.group(1))
    return {n for n in out if n and not n.startswith(".")}


print("\n".join(sorted(names(after_p) - names(before_p))))
PY
)

if [ -z "$added" ]; then
  echo "no packages added to the dependency tree"
  exit 0
fi

count=$(echo "$added" | wc -l | tr -d ' ')
echo
echo "$count package(s) added by this change — every one must be accounted for by name:"
echo

fail=0
printf "%-42s %-12s %-12s %s\n" "PACKAGE" "AGE(days)" "DL/week" "NOTE"
printf "%-42s %-12s %-12s %s\n" "------------------------------------------" "------------" "------------" "----"

while IFS= read -r pkg; do
  [ -z "$pkg" ] && continue
  enc=$(printf '%s' "$pkg" | sed 's|/|%2f|g')
  meta=$(curl -sf --max-time 15 "$REGISTRY/$enc" 2>/dev/null || echo "")
  dl=$(curl -sf --max-time 15 "$API/$enc" 2>/dev/null | python3 -c "
import json,sys
try: print(json.load(sys.stdin).get('downloads', -1))
except Exception: print(-1)" 2>/dev/null || echo "-1")

  if [ -z "$meta" ]; then
    printf "%-42s %-12s %-12s %s\n" "$pkg" "?" "?" "NOT ON REGISTRY — verify this exists and is the package the docs name"
    fail=1
    continue
  fi

  age=$(printf '%s' "$meta" | python3 -c "
import json,sys,datetime
try:
    d=json.load(sys.stdin)
    created=d['time']['created'][:10]
    delta=(datetime.date.today()-datetime.date.fromisoformat(created)).days
    print(delta)
except Exception:
    print(-1)" 2>/dev/null || echo "-1")

  note=""
  if [ "$age" != "-1" ] && [ "$age" -lt "$MIN_AGE_DAYS" ]; then
    note="NEW (<${MIN_AGE_DAYS}d) — a malicious package is always new"
    fail=1
  fi
  if [ "$dl" != "-1" ] && [ "$dl" -lt "$MIN_DOWNLOADS" ]; then
    note="${note:+$note; }LOW USE (<${MIN_DOWNLOADS}/wk) — confirm the name against the docs"
    fail=1
  fi
  printf "%-42s %-12s %-12s %s\n" "$pkg" "$age" "$dl" "$note"
done <<< "$added"

echo
if [ "$fail" -eq 1 ]; then
  cat <<'MSG'
FAIL — at least one added package is new, little-used, or not on the registry.

This is not proof of malice; it is the signal that the package has not been vetted by
anyone else yet. Before merging, confirm by hand:
  - Does the name match what the official docs say? Typosquats ride on one character
    (crossenv, lodahs), and AI-suggested dependencies routinely invent plausible names
    that squatters then register precisely because models keep recommending them.
  - Never install a package because it appeared in generated code. Look it up.
  - Check the repository, the maintainer, and the publish date.
  - Prefer --ignore-scripts where the toolchain tolerates it; install scripts are the
    usual payload.

Override deliberately (MIN_AGE_DAYS / MIN_DOWNLOADS) once you have actually checked.
MSG
  exit 1
fi

echo "PASS — every added package is established. Still read the list above; this checks"
echo "age and usage, not intent."
