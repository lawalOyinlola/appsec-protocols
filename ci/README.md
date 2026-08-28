# CI — the automatable subset

Copy what you need into a consuming project. Nothing here is specific to this repository
except the ruleset self-test.

## What is actually automatable

Of the 43 security controls, **17 (39%) can be checked by CI**. The other 26 cannot, and
saying so plainly is the point — a pipeline that implies full coverage is worse than no
pipeline, because it converts an unknown into a false reassurance.

| Tier | What it needs | Controls | Count | Status |
| :---: | --- | --- | ---: | --- |
| 1 | The source, and the repository's own settings | 1, 2, 3, 15, 17, 22, 23, 31, 33, 34, 36, 43 | 12 | **built** — `pr-gate.yml` |
| 2 | A deployed URL | 9, 20, 21, 27, 28 | 5 | designed, not built |
| 3 | A running app and a test database | 4, 6, 7, 8, 11, 13, 14, 16, 18, 19, 24, 25, 26, 29, 30, 32, 40, 41, 42 | 19 | a contract, not a scanner |
| 4 | A person, and the date they did it | 5, 10, 12, 35, 37, 38, 39 | 7 | cannot be automated |

**Control 43 is Tier 1 but is not wired into `pr-gate.yml`.** Its check is a single command
against the forge API, so it needs no running app — but reading branch protection requires the
`administration` scope, which the default workflow token does not carry. Wiring it in means an
explicit permission grant or a PAT, and a gate that needs elevated credentials to check itself
is a tradeoff worth making deliberately rather than by default. Run it by hand, or in a job you
have chosen to give that scope:

```bash
gh api repos/:owner/:repo/branches/main/protection \
  --jq '{checks: .required_status_checks.contexts, admins: .enforce_admins.enabled}'
```

**Control 13 (JWT) is the instructive case.** The ruleset does catch its static tells — an
unpinned `algorithms` allowlist, `jwt.decode` used as verification, `alg: none`. But the
control's actual verify step is to re-sign a token with `alg: none`, re-sign it with HS256
using your public key as the HMAC secret, and replay it after logout. That needs a running
app, so 13 stays Tier 3. Static coverage of a control is not the same as discharging it, and
this table counts the verify step, not the grep.

Tier 3 is the one people expect a tool to do and it cannot. Those controls are verified by
tests the *consuming project* writes against its own routes and data — no third party can
know what your ownership model is. The protocol gives you the assertion for each; you write
the test.

Tier 4 controls are satisfied by doing something and recording when. Control 37 states the
rule that governs the whole tier: *if you cannot name the date you last proved a restore, the
control is FAIL.*

## Files

| File | Purpose |
| --- | --- |
| `pr-gate.yml` | GitHub Actions workflow. Secret scan, SAST, dependency audit, lockfile vetting. |
| `semgrep/appsec-protocols.yml` | 19 rules covering controls 3, 15, 17, 31, 33, 34, 36, plus static patterns for 13. Each rule carries its control number and ASVS ids. |
| `semgrep/fixtures/` | Vulnerable and correct code the rules are tested against. |
| `scripts/test-semgrep-rules.sh` | Asserts every rule fires on vulnerable code and none fire on correct code. |
| `scripts/lockfile-diff.sh` | Control 23. Lists packages a PR adds and flags new, little-used, or non-existent ones. |

## Why the ruleset has its own test suite

Three failure modes, all silent, all caught during development by this harness:

**A rule that never fires.** The fixtures originally lived in `semgrep/tests/`, and semgrep's
default ignore list skips any path containing `tests` — so the first full run reported *zero
findings across every rule* and looked like a pass. A rule nobody has watched fire is not a
control, it is a line in a config file.

**A rule that always fires.** The SQL-interpolation rule initially flagged Prisma's
`$queryRaw` tagged template, which is the *correct* parameterized idiom and is
character-for-character similar to the unsafe form. A gate that flags correct code gets
switched off by whoever has to merge, which is the same as not having it.

**A rule that looks healthy while half of it is dead.** The control 3 rule combined
service-role-key patterns with a hardcoded-literal pattern under one `metavariable-regex`.
That constraint applies to *every* branch of a `pattern-either`, including branches that
never bind the metavariable — so the service-role patterns, the distinctive part of the
control, silently matched nothing. The rule still fired, because the literal branch did, so
the per-rule assertion passed. It is now two rules, and both must fire independently.

That third one is the uncomfortable lesson: the test harness itself gave a green result for a
rule that was half broken. Asserting "the rule fired" is weaker than asserting "each thing
the rule claims to catch was caught," and the fix was structural — split the rule until each
assertion means something — rather than a better assertion.

So: `test-semgrep-rules.sh` runs in CI alongside the rules themselves.

```bash
ci/scripts/test-semgrep-rules.sh
```

## Control 23 in practice

`lockfile-diff.sh` checks the npm registry for every package a PR adds:

```
PACKAGE                     AGE(days)   DL/week      NOTE
express                     5721        132885414
lodahs                      2468        85           LOW USE (<1000/wk) — confirm the name
react-secure-auth-helper    ?           ?            NOT ON REGISTRY — verify this exists
```

Two different failures. `lodahs` is a real typosquat of `lodash` that has sat on npm for years
— **the age check does not catch it, the usage check does**, which is why both signals are
needed. `react-secure-auth-helper` does not exist at all: that is the shape of an
AI-hallucinated dependency, the name a squatter registers precisely because models keep
suggesting it.

The script does not decide. It produces the list a human must account for by name.

## Honest limits

- The gate runs on the source it is given. Control 1's bundle grep **skips rather than
  passes** when no build output is present, and says so in the log.
- Semgrep rules are syntactic. They find the patterns, not the reachability — a flagged sink
  may be safe in context, and an unflagged one may not be.
- `npm audit` reports known CVEs in real packages. Control 23 exists because that is a
  different question from whether a package is malicious by design.
- A green run is evidence about Tier 1. It is not an audit, and it must not be quoted as one.
