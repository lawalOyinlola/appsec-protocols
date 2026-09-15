#!/usr/bin/env bash
# ci/scripts/vet-agent-installs.sh
#
# Control 44 helper: inventory every HTTP(S) URL and every MCP/plugin
# executable source reachable from agent configuration files.
#
# URL output: userinfo and credential-bearing query/fragment parameters are
# redacted before printing. Host, path, and non-sensitive values are preserved.
#
# Executable output: command names and package identifiers are printed as-is;
# values that follow a credential-bearing flag (--token, --key, --api-key,
# --secret, --client-secret, --auth, --password, --credential) are replaced
# with REDACTED. Executable names, package ids, versions, and integrity pins
# are always preserved.
#
# Usage: bash ci/scripts/vet-agent-installs.sh
# Review every line printed. Any URL that is not an immutable reference (pinned
# commit or content digest) or a vendored copy is a finding. Any executable
# source that is not integrity-locked or vendored is a finding.

set -euo pipefail

AGENT_SOURCES=(
  "$HOME/.claude/skills/"
  "$HOME/.claude/plugins/"
  ".claude/skills/"
  ".claude/plugins/"
  "$HOME/.claude.json"
  ".mcp.json"
)

# ── 1. HTTP(S) URL inventory ──────────────────────────────────────────────────

echo "=== HTTP(S) URLs ==="
grep -rEoh 'https?://[^[:space:])"]+' "${AGENT_SOURCES[@]}" 2>/dev/null \
  | sed -E \
      -e 's|(https?://)[^/@]+@|\1|g' \
      -e 's/([?&#](token|key|api_key|secret|client_secret|sig|signature|auth|access_token|X-Amz-Signature|X-Amz-Security-Token)=)[^&#[:space:]]*/\1REDACTED/gi' \
  | sort -u \
  || true

# ── 2. MCP / plugin executable-source inventory ───────────────────────────────

echo ""
echo "=== Executable sources (command + args) ==="
python3 - <<'PYEOF'
import json, re, pathlib, os, sys

CRED = re.compile(
    r'^--?(token|key|api[_-]key|secret|client.secret|auth|password|credential)',
    re.IGNORECASE,
)

SOURCES = [
    '~/.claude.json',
    '.mcp.json',
    '~/.claude/plugins',
    '.claude/plugins',
]

results = []

for src in SOURCES:
    p = pathlib.Path(os.path.expanduser(src))
    if p.is_dir():
        files = list(p.rglob('*.json'))
    elif p.is_file():
        files = [p]
    else:
        continue

    for f in files:
        try:
            data = json.loads(f.read_text())
        except (json.JSONDecodeError, OSError):
            continue

        for cfg in data.get('mcpServers', {}).values():
            cmd = cfg.get('command', '')
            if not cmd:
                continue

            args = cfg.get('args', [])
            redacted_args = []
            skip_next = False

            for arg in args:
                arg = str(arg)
                if skip_next:
                    redacted_args.append('REDACTED')
                    skip_next = False
                elif CRED.match(arg):
                    redacted_args.append(arg)
                    skip_next = True
                else:
                    redacted_args.append(arg)

            results.append(cmd + (' ' + ' '.join(redacted_args) if redacted_args else ''))

for line in sorted(set(results)):
    print(line)
PYEOF
