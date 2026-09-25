#!/usr/bin/env bash
# Plants credentials in a throwaway agent config and asserts none reach the output and every
# source is inventoried. Credentials are generated at run time, so the secret scan has no
# token-shaped literal to flag.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/ci/scripts/vet-agent-installs.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAKE_HOME="$WORK/home"
PROJECT="$WORK/project"
mkdir -p "$FAKE_HOME/.claude/skills" "$FAKE_HOME/.claude/plugins/demo/.claude-plugin" \
  "$FAKE_HOME/elsewhere/linked-skill" "$PROJECT/.claude/skills/local"

canary() { printf 'canary%s%s' "$1" "$RANDOM"; }
C_USERINFO=$(canary userinfo)
C_HYPHEN=$(canary hyphen)
C_CLIENT=$(canary client)
C_FLAG_EQ=$(canary flageq)
C_FLAG_NEXT=$(canary flagnext)
C_ENV_ARG=$(canary envarg)
C_HEADER=$(canary header)
C_ENV_BLOCK=$(canary envblock)
C_NESTED=$(canary nested)
C_FRAGMENT=$(canary fragment)
C_ENCODED=$(canary encoded)
# Lowercase URL values under env/headers: redaction by shape would miss them.
C_ENV_URL=$(canary envurl)
C_HDR_URL=$(canary hdrurl)
C_BAD_JSON=$(canary badjson)
ENC_TOKEN="ghp%5F$(printf 'Cd2%.0s' {1..12})"
GH_TOKEN="ghp_$(printf 'Ab1%.0s' {1..12})"
MIXED="$(printf 'Qx7%.0s' {1..10})"
SHA="$(printf 'a1%.0s' {1..20})"

cat > "$FAKE_HOME/elsewhere/linked-skill/SKILL.md" <<EOF
Fetch https://raw.githubusercontent.com/org/repo/$SHA/guide.md before starting.
Then https://user:$C_USERINFO@docs.example.com/path?ref=v1.2.0&api-key=$C_HYPHEN
And https://example.com/cb?Client-Secret=$C_CLIENT#access_token=$C_FRAGMENT
And https://hooks.example.com/services/$MIXED
And https://[2001:db8::44]/mcp?%74oken=$C_ENCODED&v=$ENC_TOKEN (IPv6).
EOF
ln -s "$FAKE_HOME/elsewhere/linked-skill" "$FAKE_HOME/.claude/skills/linked-skill"

# Manifest whose mcpServers is a path string: must not crash the scan.
printf '{"name": "demo", "mcpServers": "./.mcp.json"}\n' \
  > "$FAKE_HOME/.claude/plugins/demo/.claude-plugin/plugin.json"

# Pretty-printed, multiline args with every credential form.
cat > "$FAKE_HOME/.claude/plugins/demo/.mcp.json" <<EOF
{
  "mcpServers": {
    "plugin-server": {
      "command": "npx",
      "args": [
        "-y",
        "@scope/plugin-server@1.4.2",
        "--api-token=$C_FLAG_EQ",
        "--client-secret",
        "$C_FLAG_NEXT",
        "-e",
        "SERVICE_PASSWORD=$C_ENV_ARG",
        "--header",
        "Authorization: Bearer $C_HEADER",
        "$GH_TOKEN"
      ],
      "env": {"SERVICE_TOKEN": "$C_ENV_BLOCK", "WEBHOOK_URL": "https://hooks.example.com/services/$C_ENV_URL"}
    }
  }
}
EOF

# Local-scope servers live under projects.<path>.mcpServers in ~/.claude.json.
cat > "$FAKE_HOME/.claude.json" <<EOF
{
  "mcpServers": {"global-server": {"command": "uvx", "args": ["global-server==0.3.1"]}},
  "projects": {
    "/some/project": {
      "mcpServers": {
        "nested-server": {"command": "pipx", "args": ["run", "nested-server", "--key", "$C_NESTED"]},
        "remote-server": {"type": "http", "url": "https://mcp.example.com/mcp?token=$C_NESTED",
                          "headers": {"X-Callback": "https://cb.example.com/$C_HDR_URL"}}
      }
    }
  }
}
EOF

printf '{"mcpServers": {"project-server": {"command": "node", "args": ["./server.js"]}}}\n' \
  > "$PROJECT/.mcp.json"
printf 'See https://example.org/local-skill\n' > "$PROJECT/.claude/skills/local/SKILL.md"

# Malformed JSON: nothing inside may be printed, and the file must be named on stderr.
printf '{"mcpServers": {"broken": {"command": "node",\n  "env": {"HOOK": "https://hooks.example.com/%s"},\n}}}\n' \
  "$C_BAD_JSON" > "$FAKE_HOME/.claude/plugins/demo/broken.json"

output=$(cd "$PROJECT" && HOME="$FAKE_HOME" bash "$SCRIPT" 2>"$WORK/stderr")

fail=0
echo "== no planted credential may be printed =="
for secret in "$C_USERINFO" "$C_HYPHEN" "$C_CLIENT" "$C_FLAG_EQ" "$C_FLAG_NEXT" "$C_ENV_ARG" \
  "$C_HEADER" "$C_ENV_BLOCK" "$C_NESTED" "$C_FRAGMENT" "$GH_TOKEN" "$MIXED" "$C_ENCODED" \
  "$C_ENV_URL" "$C_HDR_URL" "$C_BAD_JSON" \
  "$ENC_TOKEN"; do
  if grep -qF -- "$secret" <<<"$output"; then
    echo "FAIL — leaked ${secret:0:14}…"
    fail=1
  fi
done
[ "$fail" -eq 0 ] && echo "PASS"

echo "== every planted source must be inventoried =="
missing=0
for expected in \
  "https://raw.githubusercontent.com/org/repo/$SHA/guide.md" \
  "https://docs.example.com/path?ref=v1.2.0&api-key=REDACTED" \
  "https://example.com/cb?Client-Secret=REDACTED#access_token=REDACTED" \
  "https://hooks.example.com/services/REDACTED" \
  "https://[2001:db8::44]/mcp?%74oken=REDACTED&v=REDACTED" \
  "https://example.org/local-skill" \
  "npx -y @scope/plugin-server@1.4.2 --api-token=REDACTED --client-secret REDACTED -e SERVICE_PASSWORD=REDACTED --header Authorization: REDACTED REDACTED  [plugin-server]" \
  "uvx global-server==0.3.1  [global-server]" \
  "pipx run nested-server --key REDACTED  [nested-server]" \
  "http https://mcp.example.com/mcp?token=REDACTED  [remote-server]" \
  "node ./server.js  [project-server]"; do
  if ! grep -qF -- "$expected" <<<"$output"; then
    echo "FAIL — missing: $expected"
    missing=1
    fail=1
  fi
done
[ "$missing" -eq 0 ] && echo "PASS"

echo "== a malformed JSON file must be named for manual review =="
if grep -qF "skipped (not valid JSON, review by hand): ~/.claude/plugins/demo/broken.json" "$WORK/stderr"; then
  echo "PASS"
else
  echo "FAIL — broken.json was not reported on stderr"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "--- output ---"
  echo "$output"
  exit 1
fi
