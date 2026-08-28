---
name: legal-compliance
description: Baseline legal and regulatory controls for any app used by real people — privacy policy, terms, AI disclosure, arbitration, auto-renewal, UGC/DMCA, app-store privacy labels, and jurisdiction scoping. Load BEFORE writing or editing legal pages, launching, opening signups, adding an AI feature, adding uploads, adding subscriptions, or submitting to an app store or platform review (Meta, Apple, Google, Stripe). Triggers on "privacy policy", "terms of service", "ToS", "arbitration", "DMCA", "UGC", "AI disclosure", "FTC", "GDPR", "CCPA", "COPPA", "privacy nutrition label", "data safety", "auto-renew", "click to cancel", "cookie banner", "am I going to get sued", "is this legal", "compliance", plus any task touching legal pages, subscriptions, uploads, or personal data.
---

# Legal Compliance

Baseline legal controls for software that real people use. Companion to
`security-protocols`: that skill keeps data from leaking, this one keeps the product from
being unlawful or deceptive. **Every control has a verification step — a control is not
"done" until it has been proven by reading the live page, the code, or the filing.**

## How to use this skill

- **Writing or editing legal pages** → work Group A, then whichever of C–F the jurisdiction
  gate (Group B) actually opens.
- **Pre-launch / pre-platform-review** → work all groups in order, write results to
  `tasks/legal-audit.md` (one line per control: `PASS` / `FAIL` / `N/A + why`).
- **"Not applicable" is a valid and common answer** — most controls here do not apply to
  most apps — but it must be justified in one line. Silence is not.

### Two rules that override everything else in this skill

**1. You are not a lawyer, and neither is the user's source.** This skill scopes and
prioritises; it does not give legal advice. When exposure is real and material — a
regulator, a class of consumers, employee surveillance, children's data, health or
financial data — say plainly that this needs a qualified lawyer in the relevant
jurisdiction, and keep going with what you *can* do. Never let "get a lawyer" become a
reason to deliver nothing.

**2. Verify the claim before acting on it.** Legal claims reach users through viral videos,
Twitter threads and vendor marketing, and they are frequently wrong, stale, or
jurisdiction-confused in ways that produce real wasted work. Before implementing any
specific claim, check three things:

- **Is the rule current?** Rules get struck down. The FTC's "click-to-cancel" Negative
  Option Rule, for instance, was vacated by the Eighth Circuit in 2025 — citing it as
  binding federal law would be wrong. Search for the rule's current status.
- **Does it reach this user?** Nearly every alarming figure in circulation is US federal
  or state law. A company incorporated outside the US, serving non-US customers, is
  often simply outside that reach. Establish jurisdiction (Group B) *first*.
- **Is the penalty figure real?** Statutory maxima are per-violation ceilings under
  specific statutes or consent orders, adjusted annually — not the automatic price of a
  missing sentence. Never repeat a dollar figure you have not sourced.

Tell the user plainly when a claim they brought does not apply to them, and why. Agreeing
that everything applies is not caution — it is wasted work and false comfort, and it
crowds out the risks that *are* real for them.

---

## Group A — Foundations (every app with real users)

### 1. Privacy policy exists and is publicly reachable
Required by essentially every platform (Meta, Apple, Google, Stripe) and most privacy law.
- **Verify:** fetch it signed-out and assert a 200, not a redirect:
  `curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" https://<domain>/privacy`
- **Common failure:** the page exists but sits behind auth middleware, so reviewers and
  crawlers get bounced to `/login`. Check the route-protection allowlist explicitly.
- **Also:** no dead `href="#"` links in the footer.

### 2. Terms of service exists and is publicly reachable
Terms are what let you suspend abusive accounts and cap liability.
- **Verify:** same check as control 1, against the terms route:
  `curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" https://<domain>/terms`
- **Same common failure:** reachable while signed in, bounced to `/login` when signed out.

### 3. State what data is collected, specifically
Enumerate real categories from the actual schema — not boilerplate. Read the data model
before writing this section.
- **Verify:** diff the policy's list against the database schema and any analytics/SDK
  calls. Anything collected and unlisted is a defect.

### 4. Name third-party processors
Every service that receives personal data: email, SMS/WhatsApp, analytics, maps, hosting,
payments, error tracking, AI providers.
- **Verify:** cross-check against the CSP `connect-src`, the dependency list, and env vars
  for third-party API keys. Those three catch what memory misses.

### 5. Deletion, export, and correction path
Say how a user asks, and what happens on account closure. Retention claims must match
reality.
- **Verify:** find the code that actually deletes. If a cleanup job only prunes some
  tables, the policy must not claim more. **A retention promise the code does not keep is
  a false statement in a privacy policy** — the worst kind of defect here, because it is
  written down and dated.

### 6. Working contact channel
A real, monitored address — not a role alias that forwards nowhere.
- **Verify:** send a message to the published address from an unrelated account and confirm it
  arrives. An address that bounces is worse than none: it is a published promise you are
  visibly failing, and it is the channel a regulator or platform reviewer will try first.

### 7. Identify the legal entity accurately
Legal name, registered address, and registration number where applicable — matching the
incorporation documents exactly.
- **Verify:** compare against the certificate of incorporation, character for character.
  Trading names, abbreviations, and punctuation variants all cause platform rejections.
- **Watch for:** registered address on the certificate differing from the operating
  address. Pick one, use it consistently everywhere, and expect to explain the other.

---

## Group B — Jurisdiction gate (decide before applying C–F)

### 8. Establish reach before applying any rule
Answer these four, in the project's docs, before implementing anything from Groups C–F:

| Question | Why it decides things |
| --- | --- |
| Where is the entity incorporated? | Sets default governing law and regulator |
| Where do users actually live? | US → FTC/state law. EU/UK → GDPR. Both → both |
| B2C or B2B? | Class actions and consumer-protection rules mostly target B2C |
| How is it distributed? | App Store/Play impose their own regime; web-only does not |

- **Verify:** write the four answers down. If the answer is "no US users", most US-specific
  controls below are `N/A` and should be recorded as such rather than implemented.
- **Governing law + venue clause** in the Terms is the cheapest control in this skill and
  does much of the work that panicked founders attribute to arbitration clauses.

---

## Group C — US-facing (only if serving US users)

### 9. Do not make deceptive claims, including about AI
The FTC's actual concern is **deception**, not the absence of a disclosure sentence.
Claiming capability the product lacks ("AI-powered" when it is if/else, "bank-level
security") is the violation.
- **Verify:** every capability claim on the landing page maps to shipped code.
- **If the product genuinely uses AI:** say so where a user would reasonably want to know
  — especially if AI output affects decisions about them, or if they might mistake it for
  a human. This is cheap and worth doing regardless of jurisdiction.

### 10. Arbitration and class-action waiver
Enforceable in the US and genuinely limits class exposure for **B2C** products. Much less
relevant B2B, and **unenforceable against consumers in much of the EU/UK**.
- **Verify:** if added, it must be conspicuous and mutual. A buried clause is struck.
- **Judgment:** for a non-US B2B product, a governing-law and exclusive-jurisdiction clause
  usually matters more. Do not bolt a US arbitration clause onto a product with no US
  users and call it protection.

### 11. Subscription auto-renewal and cancellation
If billing recurs: disclose price, interval and renewal *before* purchase, and make
cancellation reachable without a support ticket.
- **Verify:** click through the real cancel flow. Count the steps against signup.
- **Status check:** the FTC's click-to-cancel rule was vacated in 2025, but **state laws
  (notably California's ARL) still bind**, as do Apple/Google/Stripe rules. Check current
  status rather than citing the federal rule.

### 12. DMCA designated agent — only if hosting user uploads
Safe harbour under 17 U.S.C. §512 requires registering an agent with the US Copyright
Office (small fee, renewable) **and** a takedown process in the Terms.
- **Verify:** does the app actually accept user-uploaded content? Grep for upload
  handlers and file inputs. **No uploads → `N/A`.** This is the control most often
  cargo-culted onto apps that have no UGC at all.

### 13. State privacy laws (CCPA/CPRA and successors)
Trigger on thresholds (revenue, volume of consumers, data sales). Below threshold → record
`N/A` with the reason.
- **Verify:** check current thresholds; do not assume. If in scope: "Do Not Sell/Share"
  link, opt-out honouring, and a rights-request path.

---

## Group D — EU/UK (only if serving EU/UK users)

### 14. GDPR essentials
Lawful basis per purpose; controller vs processor roles stated; processor agreements in
place; data-subject rights honoured within statutory deadlines; breach notification path;
international transfer safeguards.
- **Verify:** the policy names a lawful basis, not just a purpose. For B2B, state clearly
  which data the customer controls and which you control — this determines who answers a
  data-subject request.

### 15. Cookies and tracking
Consent required *before* setting non-essential cookies. Strictly-necessary cookies
(session, CSRF) do not need consent and should be described as such.
- **Verify:** load the site fresh and inspect what is set before any interaction.

---

## Group E — App store distribution (only if shipping a native app)

### 16. Apple Privacy Nutrition Label / Google Play Data Safety
Required for App Store and Play distribution. Must list every collected data type,
**including what SDKs collect on your behalf** — analytics, ads, crash reporting.
- **Verify:** enumerate SDKs, then reconcile against the declared label. An undeclared
  SDK is a rejection and a misrepresentation.
- **Web apps and PWAs distributed outside the stores → `N/A`.** A `manifest.webmanifest`
  is not store distribution.

---

## Group F — Product-specific high risk

### 17. Location, biometric, and health data
Location history is sensitive: it reveals home, routine, associations. Biometric data
carries statutory damages under laws such as Illinois BIPA.
- **Verify:** state retention plainly, keep tenants isolated, and never repurpose it.
- **Employee/driver tracking is its own risk**, separate from customer privacy: workers
  usually must be *informed*, and in some jurisdictions must consent. Put the obligation
  on the customer explicitly in the Terms, and give them the wording to pass on.

### 18. AI features
If AI touches user data: name the provider as a processor (Group A.4), say whether inputs
train third-party models, and disclose AI involvement where a user would care.
- **Verify:** check the provider's data-retention terms and whether a zero-retention or
  no-training option exists. If user content is sent to a model, the policy must say so.
- **Disclosure is the legal half; the technical half is `security-protocols` 29–30** (prompt
  injection, and per-user cost caps). Neither substitutes for the other.
- **If AI output could affect safety** — health, legal, financial, crisis or self-harm
  contexts — there must be a defined safe response and a human escalation path. This is a
  product requirement, not a legal footnote.

### 19. Children
If under-13 (US) or under-16 (parts of EU) users are plausible, COPPA/GDPR-K obligations
attach and they are heavy.
- **Verify:** state a minimum age in the Terms and mean it. "Not intended for children" in
  a policy while the product courts them is exactly the deception regulators pursue.

### 20. Payments
Never handle raw card data — use a processor's hosted flow so PCI scope stays with them.
- **Verify:** confirm no PAN reaches your servers or logs. State in the policy that the
  processor handles payment details.
- **`security-protocols` 42 is the matching technical control** — server-side pricing, and the
  signed webhook as the source of truth for "paid". A checkout the client can re-price is a
  consumer-protection problem as well as a security one.

---

## Reporting

Never report "legally compliant" — that is not a thing you can determine. Report per
control, with evidence:

```
A.1 Privacy policy reachable   PASS  curl → 200, no redirect, signed out
A.5 Retention matches code     FAIL  policy claims 90-day deletion; cleanup job
                                     only prunes stale invites, positions kept
C.12 DMCA agent                N/A   no user uploads (no upload handlers in src)
```

Then state, in one sentence each: what is genuinely exposed, what is `N/A` and why, and
what needs a real lawyer.
