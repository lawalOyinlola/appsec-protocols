# appsec-protocols

**Security, legal and kickoff checklists compiled into executable agent skills. Every control
has a command, not a claim.**

Three skills for [Claude Code](https://claude.com/claude-code) and compatible agent runtimes.
They load automatically when an agent is about to write the code they govern — auth, database
access, file uploads, API endpoints, payment flows, legal pages, deploy config — rather than
after, when the finding is a rewrite instead of a line.

| Skill | Controls | Scope |
| --- | --- | --- |
| [`security-protocols`](skills/security-protocols/SKILL.md) | 43 | Is the product **safe**? Secrets, data access, sessions, input/output, transport and supply chain, request surface, LLM features, injection surfaces, operations. |
| [`legal-compliance`](skills/legal-compliance/SKILL.md) | 20 | Is the product **lawful**? Privacy policy, terms, AI disclosure, arbitration, auto-renewal, UGC/DMCA, app-store privacy labels — behind a jurisdiction gate. |
| [`project-kickoff`](skills/project-kickoff/SKILL.md) | 18 | What must be true **before the first feature commit**. PRD, non-goals, ICP, locked stack, repo hygiene, environment separation, error tracking. |

**81 controls. 81 verification steps.** That ratio is the design constraint, and it is
mechanically checkable:

```bash
for f in skills/*/SKILL.md; do
  echo "$(basename $(dirname $f)): controls=$(grep -cE '^### [0-9]+\.' $f) verify=$(grep -c 'Verify:' $f)"
done
```

## The thesis

Most security checklists are *declarative*. They tell you what should be true:

> Verify that session tokens are invalidated when the password is changed.

True, and useless at 2am — because it does not tell you what you would *do* to find out. So
the item gets read, silently agreed with, ticked, and never tested. That is how a checklist
becomes theatre.

Every control here is written the other way round. Control 9, same requirement:

> Kill *every* session on password change or reset — not just the current one. The whole point
> of a reset is evicting an attacker who already has a live session; leaving their other
> sessions valid defeats it. Store a `sessionsValidAfter` timestamp (or token version) per user
> and reject anything issued earlier.
>
> **Verify:** log in on two browsers, change the password in one, refresh the other — expect 401.

That last line is the entire point. It cannot be satisfied by agreeing with it. Either you ran
it and saw a 401, or the control is unverified — and unverified is a reportable state, not a
pass.

## Three rules the skills enforce on themselves

1. **Never report "all secure."** Report which controls pass, which fail, and which were not
   checked. A blanket claim of safety is the least informative possible output of an audit, and
   the easiest to fabricate.
2. **"Not applicable" is a valid answer — silence is not.** Most legal controls do not apply to
   most apps. Marking one `N/A` is fine; it costs one line of justification. Skipping it
   quietly is not.
3. **Verify the claim before acting on it.** Especially in `legal-compliance`, where the
   alarming figures in circulation are usually US law that may not reach the user at all,
   sometimes stale, and often a per-violation statutory ceiling quoted as if it were the price
   of a missing sentence. The jurisdiction gate runs *before* any US or EU control does.

## Install

Clone, then symlink each skill into your agent's skills directory:

```bash
git clone https://github.com/lawalOyinlola/appsec-protocols.git
cd appsec-protocols

for n in security-protocols legal-compliance project-kickoff; do
  ln -s "$PWD/skills/$n" ~/.claude/skills/$n
done

# verify all three resolve
for n in security-protocols legal-compliance project-kickoff; do
  [ -f ~/.claude/skills/$n/SKILL.md ] && echo "OK $n" || echo "BROKEN $n"
done
```

Use absolute paths — a relative symlink breaks as soon as it crosses directory trees. A skill
directory that is not symlinked into the skills path is silently never registered: the slash
command simply does not exist, with no error to tell you so.

## Use

- **While building** — the skills load on their own when the work touches what they govern.
  Read the relevant group *before* writing the code.
- **As an audit** — invoke directly (`/security-protocols`, `/legal-compliance`,
  `/project-kickoff`) and work every control in order. Results go to `tasks/security-audit.md`,
  `tasks/legal-audit.md`, `tasks/kickoff-audit.md` in the consuming project: one line per
  control, `PASS` / `FAIL` / `N/A + why`.
- **Before a launch** — run `security-protocols` and `legal-compliance` both. They are
  deliberately separate: one keeps data from leaking, the other keeps the product from being
  unlawful or deceptive, and passing either says nothing about the other.

## Relationship to OWASP ASVS

[ASVS 5.0](https://owasp.org/www-project-application-security-verification-standard/) is the
standard, and it is more comprehensive than this by an order of magnitude — roughly 350
requirements across 17 chapters, maintained by a working group. This is not a competitor to it
and should not be read as one.

What this adds is downstream: a triaged subset sized for one person shipping a product, with an
executable verification step attached to each item, and reporting rules that make a dishonest
audit harder to produce. Where the two disagree, ASVS is right — and in at least one place it
already is: ASVS V4.1.2 says only user-facing endpoints should auto-redirect HTTP to HTTPS,
because redirecting API endpoints teaches clients that plaintext is acceptable. Control 21 says
redirect everything. ASVS is more precise, and the mapping records that.

**[mapping/asvs-5.0-coverage.md](mapping/asvs-5.0-coverage.md) is the honest version of this
claim**, generated against the released standard with every citation machine-validated:

- **118 of 345 ASVS 5.0 requirements (34%)** are touched by at least one of the 43 controls.
  The other 227 are not.
- **Strongest:** V9 Self-contained Tokens (85%), V13 Configuration (66%), V5 File Handling (61%).
- **Weakest:** V17 WebRTC (0%, out of scope by design), V6 Authentication (10% of 47
  requirements — MFA, recovery flows and password policy detail are simply absent), V12 Secure
  Communication (16%), V10 OAuth/OIDC (22% of 36 requirements against a single control).
- **Two controls have no ASVS counterpart at all:** control 37 (backup and restore proof) and
  control 43 (an unbypassable CI gate). ASVS verifies the application, not the operational
  practice around it nor the pipeline that ships it.

So: use this to get a product shipped without the common failures. Read ASVS directly before
doing serious work on authentication, OAuth, or cryptography, where the gap is widest. The
mapping exists so you can see *which* is which rather than taking my word for the coverage.

## Status

Honest state of the work, in the format the skills demand:

| Item | State |
| --- | --- |
| 43 / 20 / 18 controls, each with a verify step | **PASS** — 81/81, checkable with the command above |
| Numbering sequential, cross-references resolve | **PASS** — verified 2026-08-28 |
| ASVS 5.0 chapter mapping | **PASS** — [generated](mapping/asvs-5.0-coverage.md), 118/345 requirements touched, all 118 citations validated against the released standard |
| CI: PR gate (secret scan, SAST, dependency audit, lockfile vetting) | **PASS** — [`ci/`](ci/), 19 semgrep rules, all tested against fixtures |
| CI: post-deploy probe (headers, HTTPS, surface enumeration) | **DESIGNED, NOT BUILT** |
| Distribution as a Claude Code plugin | **UNVERIFIED** — manifest schema not confirmed against current docs |

**17 of the 43 security controls (39%) are mechanically checkable by CI this repo can ship** —
12 at the PR gate, 5 against a deployed URL. Of the rest, 19 are a contract the consuming
project must write tests for and 7 are actions someone takes and dates. The per-tier breakdown
is in the mapping. Being explicit about which is which is more useful than automating the easy
half and implying the rest.

Aligned to the threat landscape as of **2026-08**. Security guidance goes stale, and stale
guidance actively misleads — if this date is far behind you, treat the specifics as suspect.

## CI

[`ci/`](ci/) implements the Tier 1 PR gate: gitleaks, a 19-rule semgrep ruleset written
against these controls, a dependency audit, and lockfile vetting for control 23.

The ruleset has its own test suite ([`ci/scripts/test-semgrep-rules.sh`](ci/scripts/test-semgrep-rules.sh)),
which asserts every rule fires on vulnerable code and none fire on correct code. Both halves
caught real bugs while it was being built — semgrep's default ignore list skips any path
containing `tests`, so the first full run reported zero findings across every rule and
looked like a pass; and the SQL rule flagged Prisma's `$queryRaw` tagged template, which is
the correct parameterized idiom.

Control 23's check queries the registry for every package a PR adds:

```
PACKAGE                     AGE(days)   DL/week      NOTE
express                     5721        132885414
lodahs                      2468        85           LOW USE (<1000/wk) — confirm the name
react-secure-auth-helper    ?           ?            NOT ON REGISTRY — verify this exists
```

`lodahs` is a real typosquat of `lodash`, years old, which an age check misses and a usage
check catches. `react-secure-auth-helper` does not exist — the shape of an AI-hallucinated
dependency, the name a squatter registers because models keep suggesting it.

## Disclaimer

**[DISCLAIMER.md](DISCLAIMER.md) — read it.** In short: `legal-compliance` is not legal advice
and creates no lawyer–client relationship; `security-protocols` is a baseline, not a guarantee,
and working all 43 controls does not make an application secure. It makes 43 common failures
less likely.

## License

[MIT](LICENSE) © 2026 Oyinlola Lawal

Corrections and disagreements are welcome as issues — several calls here are opinionated
(progressive backoff over hard lockout; validate on input *and* escape on output) and are held
because of a reason, not a habit. Bring the reason.

---

Oyinlola Lawal · [@lawalOyinlola](https://github.com/lawalOyinlola)
