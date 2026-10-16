#!/usr/bin/env bash
# Control 44: list every HTTP(S) URL and MCP server command reachable from agent config
# (skills, plugins, ~/.claude.json, .mcp.json), for review. Credentials are redacted by
# shape rather than by a list of names, and env/headers values are never printed.
#
# Usage: bash ci/scripts/vet-agent-installs.sh
# A URL that is not pinned or vendored, or an executable that is not integrity-locked,
# is a finding. Servers launched through a package runner (npx, bunx, npm exec, pnpm/yarn
# dlx, uvx, uv tool run, pipx run) without an exact version are flagged automatically,
# because every start can pull new code.

set -euo pipefail

command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 127; }

exec python3 - "$@" <<'PYEOF'
import json
import os
import re
import sys
from urllib.parse import unquote_plus, urlsplit, urlunsplit

HOME = os.path.expanduser('~')
TREES = [
    os.path.join(HOME, '.claude', 'skills'),
    os.path.join(HOME, '.claude', 'plugins'),
    os.path.join('.claude', 'skills'),
    os.path.join('.claude', 'plugins'),
]
CONFIG_FILES = [os.path.join(HOME, '.claude.json'), '.mcp.json']
MAX_BYTES = 5 * 1024 * 1024

SENSITIVE_NAME = re.compile(
    r'token|key|secret|passw|pwd|credential|auth|sig|session|cookie|bearer', re.I)
TOKEN_PREFIX = re.compile(
    r'(ghp_|gho_|ghu_|ghs_|ghr_|github_pat_|glpat-|sk-|sk_live_|rk_live_|'
    r'xox[abeprs]-|AKIA|ASIA|AIza|ya29\.|npm_|pypi-|hf_|eyJ)[A-Za-z0-9_\-.]{8,}')
URL = re.compile(
    r'https?://(?:\[[^\]\s<>"\'`(){}\\]+\]|[^\s<>"\'`()\[\]{}\\]+)'
    r'[^\s<>"\'`()\[\]{}\\]*')
FLAG = re.compile(r'^(--?)([A-Za-z0-9_.\-]+)(=(.*))?$', re.S)
ASSIGN = re.compile(r'^([A-Za-z_][A-Za-z0-9_.\-]*)(=|:\s*)(.*)$', re.S)
R = 'REDACTED'


def looks_secret(value):
    if TOKEN_PREFIX.search(value):
        return True
    # Long mixed-case alphanumerics are credentials; lowercase hex (SHAs,
    # digests) and ordinary package names are not.
    for chunk in re.findall(r'[A-Za-z0-9_\-]{20,}', value):
        if (re.search(r'[a-z]', chunk) and re.search(r'[A-Z]', chunk)
                and re.search(r'[0-9]', chunk)):
            return True
    return False


def redact_pairs(text):
    out = []
    for part in text.split('&'):
        name, eq, value = part.partition('=')
        if eq and (SENSITIVE_NAME.search(unquote_plus(name))
                   or looks_secret(unquote_plus(value))):
            value = R
        elif not eq and looks_secret(unquote_plus(name)):
            name = R
        out.append(name + eq + value)
    return '&'.join(out)


def redact_url(url):
    url = url.rstrip('.,;:!?\'"')
    try:
        parts = urlsplit(url)
    except ValueError:
        return R
    netloc = parts.netloc.rpartition('@')[2]
    path = '/'.join(R if looks_secret(unquote_plus(seg)) else seg for seg in parts.path.split('/'))
    return urlunsplit((parts.scheme, netloc, path,
                       redact_pairs(parts.query), redact_pairs(parts.fragment)))


def redact_value(value):
    m = ASSIGN.match(value)
    if m and SENSITIVE_NAME.search(m.group(1)):
        return m.group(1) + m.group(2) + R
    value = URL.sub(lambda u: redact_url(u.group(0)), value)
    if looks_secret(URL.sub('', value)):
        return R
    return value


def redact_args(args):
    out, skip_next = [], False
    for arg in args:
        arg = str(arg)
        if skip_next:
            out.append(R)
            skip_next = False
            continue
        m = FLAG.match(arg)
        if m and SENSITIVE_NAME.search(m.group(2)):
            if m.group(3) is None:
                out.append(arg)
                skip_next = True
            else:
                out.append(m.group(1) + m.group(2) + '=' + R)
            continue
        out.append(redact_value(arg))
    return out


def display(path):
    path = os.path.abspath(path)
    return '~' + path[len(HOME):] if path.startswith(HOME + os.sep) else path


def walk(tree):
    seen = set()
    for root, dirs, files in os.walk(tree, followlinks=True):
        real = os.path.realpath(root)
        if real in seen:
            dirs[:] = []
            continue
        seen.add(real)
        dirs[:] = [d for d in dirs if d != '.git']
        for name in files:
            yield os.path.join(root, name)


def read_text(path):
    try:
        if os.path.getsize(path) > MAX_BYTES:
            print('skipped (over 5 MB): ' + display(path), file=sys.stderr)
            return None
        with open(path, 'rb') as fh:
            raw = fh.read()
    except OSError:
        return None
    if b'\0' in raw[:8192]:
        return None
    return raw.decode('utf-8', errors='replace')


def find_servers(node, found):
    if isinstance(node, dict):
        for key, value in node.items():
            if key == 'mcpServers' and isinstance(value, dict):
                for name, cfg in value.items():
                    if isinstance(cfg, dict):
                        found.append((str(name), cfg))
            else:
                find_servers(value, found)
    elif isinstance(node, list):
        for item in node:
            find_servers(item, found)


SKIP_KEYS = {'env', 'headers'}


def strings_outside_secrets(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if str(key).lower() in SKIP_KEYS:
                continue
            yield from strings_outside_secrets(value)
    elif isinstance(node, list):
        for item in node:
            yield from strings_outside_secrets(item)
    elif isinstance(node, str):
        yield node


def describe(cfg):
    command = cfg.get('command')
    args = cfg.get('args', [])
    if isinstance(args, str):
        args = [args]
    elif not isinstance(args, list):
        args = []
    if isinstance(command, str) and command:
        return ' '.join([redact_value(command)] + redact_args(args))
    url = cfg.get('url')
    if isinstance(url, str) and url:
        return (str(cfg.get('type', 'remote')) + ' ' + redact_url(url))
    return None


NPM_RUNNERS = {'npx', 'bunx'}
PY_RUNNERS = {'uvx'}
# Runner flags that take a value as the next argument. Anything else starting with '-' is
# treated as a switch.
VALUE_FLAGS = {
    'npm': {'-p', '--package', '-c', '--call', '-w', '--workspace', '--registry', '--cache',
            '--userconfig', '--prefix'},
    'py': {'--from', '--with', '--with-requirements', '--with-editable', '--python', '-p',
           '--index-url', '-i', '--extra-index-url', '--index', '--default-index',
           '--find-links', '-f', '--spec', '--pip-args', '--constraint', '-c'},
}
SPEC_FLAGS = {'-p', '--package', '--from', '--spec'}
EXACT_SEMVER = re.compile(r'^v?\d+\.\d+\.\d+(?:-[0-9A-Za-z.\-]+)?(?:\+[0-9A-Za-z.\-]+)?$')
COMMIT = re.compile(r'(?:#|@)(?:commit=)?[0-9a-f]{40}$')
LOCAL = re.compile(r'^(?:\.{0,2}/|~/|[A-Za-z]:\\|file:)')


def launch_tokens(cfg):
    command = cfg.get('command')
    if not isinstance(command, str) or not command.strip():
        return []
    args = cfg.get('args', [])
    if isinstance(args, str):
        args = [args]
    elif not isinstance(args, list):
        args = []
    tokens = command.split() + [str(a) for a in args]
    # Windows configs wrap the runner: cmd /c npx ...
    if tokens and os.path.basename(tokens[0]).lower() in ('cmd', 'cmd.exe') \
            and len(tokens) > 1 and tokens[1].lower() == '/c':
        tokens = tokens[2:]
    return tokens


def package_specs(tokens):
    """Return (kind, [specs]) for a package-runner launch, or None for anything else."""
    if not tokens:
        return None
    runner = os.path.basename(tokens[0]).lower()
    rest = tokens[1:]
    if runner.endswith('.cmd') or runner.endswith('.exe'):
        runner = runner.rsplit('.', 1)[0]
    if runner in NPM_RUNNERS:
        kind = 'npm'
    elif runner in PY_RUNNERS:
        kind = 'py'
    elif runner in ('npm', 'pnpm', 'yarn') and rest and rest[0] in ('exec', 'x', 'dlx'):
        kind, rest = 'npm', rest[1:]
    elif runner == 'uv' and rest[:2] == ['tool', 'run']:
        kind, rest = 'py', rest[2:]
    elif runner == 'pipx' and rest and rest[0] == 'run':
        kind, rest = 'py', rest[1:]
    else:
        return None
    specs, i = [], 0
    while i < len(rest):
        arg = rest[i]
        if arg == '--':
            if i + 1 < len(rest) and not specs:
                specs.append(rest[i + 1])
            break
        if arg.startswith('-'):
            name, eq, value = arg.partition('=')
            if name in SPEC_FLAGS:
                if eq:
                    specs.append(value)
                elif i + 1 < len(rest):
                    specs.append(rest[i + 1])
                    i += 1
            elif not eq and name in VALUE_FLAGS[kind]:
                i += 1
            i += 1
            continue
        # The first positional is the package unless a spec flag already named it; after
        # that, everything belongs to the server.
        if not specs:
            specs.append(arg)
        break
    return kind, specs


def unpinned_reason(kind, spec):
    if LOCAL.match(spec):
        return None
    if '://' in spec or spec.startswith(('git+', 'github:', 'gitlab:', 'bitbucket:')) \
            or ' @ ' in spec:
        return None if COMMIT.search(spec) else 'source URL without a commit hash'
    if kind == 'npm':
        name, _, version = spec[1:].partition('@') if spec.startswith('@') \
            else spec.partition('@')
        if not version:
            return 'no version, resolves to latest on every start'
        if not EXACT_SEMVER.match(version):
            return 'version "%s" is a tag or range, not an exact version' % version
        return None
    # name==1.2.3, name===1.2.3, or uv's name@1.2.3. `==1.*` is a range, `@latest` a tag.
    m = re.match(r'^[A-Za-z0-9_.\-]+(?:\[[^\]]*\])?\s*(===?|@)\s*(\S+)$', spec)
    if m:
        op, version = m.groups()
        exact = EXACT_SEMVER.match(version) if op == '@' else (
            re.match(r'^v?[0-9][0-9A-Za-z.+!\-]*$', version) and '*' not in version)
        return None if exact else 'version "%s" is not an exact version' % version
    if re.search(r'[<>~!]=?|\*', spec):
        return 'version range, not an exact version'
    return 'no version, resolves to latest on every start'


files = [f for t in TREES if os.path.isdir(t) for f in walk(t)]
files += [f for f in CONFIG_FILES if os.path.isfile(f)]

urls, servers, unpinned = set(), set(), set()
for path in files:
    text = read_text(path)
    if text is None:
        continue
    data = None
    if path.endswith('.json'):
        try:
            data = json.loads(text)
        except ValueError:
            data = None
    if data is None:
        if path.endswith('.json'):
            # Unparsed JSON would expose env/headers to the raw scan.
            print('skipped (not valid JSON, review by hand): ' + display(path), file=sys.stderr)
            continue
        for m in URL.finditer(text):
            urls.add(redact_url(m.group(0)))
    else:
        for value in strings_outside_secrets(data):
            for m in URL.finditer(value):
                urls.add(redact_url(m.group(0)))
        found = []
        find_servers(data, found)
        for name, cfg in found:
            line = describe(cfg)
            if line:
                servers.add('%s  [%s]  %s' % (line, name, display(path)))
            launch = package_specs(launch_tokens(cfg))
            if launch:
                kind, specs = launch
                for spec in specs or ['']:
                    reason = unpinned_reason(kind, spec) if spec else 'no package found in args'
                    if reason:
                        unpinned.add('%s: %s  [%s]  %s' % (
                            redact_value(spec) or '?', reason, name, display(path)))

print('=== HTTP(S) URLs ===')
for url in sorted(urls):
    print(url)
print()
print('=== MCP servers (command + args, or remote url) ===')
for line in sorted(servers):
    print(line)
print()
# An exact version stops a new release reaching you on the next start. It is not integrity
# locking: the package's own dependencies still float, so vendoring is the stronger fix.
print('=== Findings: package launches without an exact version (npx, uvx, pipx run, dlx) ===')
for line in sorted(unpinned):
    print(line)
if not unpinned:
    print('none')
PYEOF
