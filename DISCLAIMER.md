# Disclaimer

Read this before using anything in this repository.

## This is not legal advice

`skills/legal-compliance/` discusses privacy law, consumer-protection rules, platform
policies and contract terms. **It is not legal advice, and using it does not create a
lawyer–client relationship with anyone.**

The author is not a lawyer. The skill exists to *scope and prioritise* legal questions so
that a founder can tell which ones plausibly reach them and which are noise — not to answer
those questions authoritatively. Where exposure is real and material (a regulator, a class of
consumers, children's data, health or financial data, employee monitoring), the skill itself
says to engage a qualified lawyer in the relevant jurisdiction. That instruction is the
important part, not the checklist around it.

Law is jurisdictional and it changes. A rule cited here may have been amended, superseded, or
struck down since this was written — the skill's own Rule 2 tells you to verify a claim's
current status before acting on it. Apply that rule to this repository too.

## This is not a security guarantee

`skills/security-protocols/` is a baseline, not a complete threat model. Working all 42
controls does not make an application secure; it makes 42 specific and common failures less
likely. It does not cover threat modelling for your particular product, business-logic flaws,
cryptographic design, physical or personnel security, or anything specific to your industry's
regulatory regime.

The protocol's own reporting rule applies to the protocol itself: **never report "all
secure."** Report which controls pass, which fail, and which were not checked.

## No warranty

The repository is provided as-is under the MIT License, without warranty of any kind. The
copyright notice's warranty disclaimer is a copyright-law instrument; this document is the
plain-language version. Neither transfers responsibility for your application to anyone but
you. You remain responsible for what you ship.

## Automated checks are partial by design

Where this repository provides CI configuration, it covers the mechanically checkable subset
of the controls and no more. A green pipeline means the automated subset passed. It is not
evidence that the remaining controls were satisfied — several of them cannot be checked by any
scanner and are satisfied only by a test you write or an action you take and date.
