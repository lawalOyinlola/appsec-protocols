---
name: security-protocols
description: Baseline security protocol (44 controls) for any app that will be used by real people. Load BEFORE writing auth, database access, file uploads, API endpoints, session handling, payment/checkout flows, LLM calls, backups, webhooks, or deploy config — and run as a full audit before any launch, beta, or public deploy. Triggers on "is this secure", "security review", "before launch", "going live", "pre-launch checklist", "harden", "pentest", "did I leak a key", "RLS", "rate limit", "CSRF", "CORS", "security headers", "prompt injection", "SSRF", "path traversal", "command injection", "IDOR", "BOLA", "XSS", "SQL injection", "NoSQL injection", "mass assignment", "insecure deserialisation", "JWT", "OAuth", "session management", "webhook signature", "audit log", "backups", "restore", "tenant isolation", "least privilege", "staging environment", "typosquatting", "branch protection", "CI/CD pipeline", "agent skill", "MCP server", "plugin marketplace", plus any task touching secrets, passwords, tokens, cookies, uploads, payments, or logs.
---

# Security Protocols

The non-negotiable baseline. Forty-three controls, grouped by the phase where they must be
enforced. **Every control has a verification step — a control is not "done" until it has been
proven with a command, a test, or an inspected response.** Claiming a control is satisfied
without running its check is a violation of this protocol.

Which groups apply:

| Group | Controls | Applies to |
| --- | --- | --- |
| A–E | 1–23 | every app |
| F | 24–28 | anything serving HTTP |
| G | 29–30 | only if it calls an LLM |
| H | 31–34 | injection surfaces — check each against the stack; several may be `N/A` |
| I | 35–44 | before launch. 40 only if multi-tenant, 41–42 only with webhooks/payments, 43 once CI exists, 44 if anyone on the team uses an AI coding agent |

## How to use this skill

- **Building a feature** → read the relevant group below *before* writing the code, not after.
- **Pre-launch audit** → work all 43 in order, and write results to `tasks/security-audit.md`
  in the project (one line per control: `PASS` / `FAIL` / `N/A + why`). Never report a blanket
  "all secure" — report per control, with the evidence.
- **Not applicable is a valid answer**, but it must be justified in one line. Silence is not.

Never weaken a control to make a task easier. If a control genuinely blocks the work, stop
and surface the tradeoff to the user rather than quietly dropping it.

This skill covers whether the product is **safe**. Whether it is **lawful** — privacy policy,
terms, AI disclosure, data-deletion rights — is `legal-compliance`. Before a launch, run both.

---

## Group A — Secrets & Keys (do this first; failures here are unrecoverable)

### 1. Hide API keys
No secret in client-side code, ever. Anything shipped to a browser or mobile bundle is public,
including `NEXT_PUBLIC_*` / `VITE_*` / `EXPO_PUBLIC_*` vars — those are for public identifiers
only. Third-party API calls that need a secret go through a server route or backend proxy.

**Where a secret lives, and who holds it.** Not committing one is half the control. The other
half is that the secret exists somewhere regardless, and every copy is a place it can leak from.
- **One source of truth:** a secret manager or the platform's encrypted environment config.
  Not a shared doc, not a pinned Slack message, not a screenshot, not a chat with an AI
  assistant. Those are permanent, searchable copies you do not control and cannot revoke.
- **Need-to-know, and prefer per-person or per-service credentials over one shared key.** A
  shared key cannot be revoked from one person — revoking it means rotating for everyone, so
  in practice nobody does, and access quietly outlives the reason for it.
- **Offboarding is a rotation, not a checkbox.** If someone who has left ever held a shared
  production secret, rotating it is the only real revocation.
- **Verify:** two checks. (1) Grep the built bundle, not the source:
  `grep -rE "sk_live|sk_test|-----BEGIN|api[_-]?key" dist/ .next/ build/`
  (2) For each production secret, name every human and system that can read it today. If you
  cannot produce that list, that *is* the finding; if it is longer than the people who
  currently need it, rotate.
- **Also:** `.env*` must be gitignored (`.env.example` with placeholder values is the committed one).

### 2. Purge Git secrets
A secret committed once is compromised forever, even after deletion — rotate first, then scrub.
- **Verify:** run a history scanner (`gitleaks detect --no-git=false`, `trufflehog git file://.`).
- **Order of operations:** (1) rotate the credential at the provider, (2) scrub history
  (`git filter-repo`) or accept it as burned, (3) add a pre-commit/CI secret scan so it can't recur.
- Pin scanner downloads to a verified checksum — a supply-chain hole in your security tooling
  is still a supply-chain hole.

### 3. Use the public/anon key client-side
Client gets the publishable/anon key. The service-role / admin / secret key is server-only and
bypasses every access rule you wrote — treat it as root.
- **Verify:** grep the client tree for `service_role`, `SUPABASE_SERVICE_KEY`, `sk_live`, admin SDK imports.
- Server-side admin clients must be constructed in files that can never be imported by client code.

---

## Group B — Data Access (the layer that actually stops a breach)

### 4. Enable row-level security
Every user-data table has RLS enabled **and** a policy. RLS on with no policy = denies all
(fails safe); RLS off = the anon key can read the whole table.
- **Verify:** `SELECT relname, relrowsecurity FROM pg_class WHERE relnamespace = 'public'::regnamespace AND relkind = 'r';`
  — any `false` on a user-data table is a FAIL.
- Prove it: authenticate as user A and attempt to read user B's row. Expect zero rows.
- On an ORM-only stack (Prisma/TypeORM without RLS), the equivalent control is: **every** query
  filters by the authenticated owner id, enforced in a shared repository/guard layer — not
  re-typed per endpoint where one omission leaks everything.

### 5. Encrypt sensitive data
TLS in transit is table stakes; this is about at-rest. Encrypt PII, tokens, and financial
identifiers at the column level with a key from the secret manager, not the repo.
- Store third-party OAuth/refresh tokens encrypted or hashed, never plaintext.
- Don't invent crypto: use the platform primitive (`node:crypto` AES-256-GCM, `pgcrypto`, KMS).
- **Verify:** query the raw table and confirm the sensitive column is unreadable ciphertext.

### 6. Enforce server-side auth
Client-side route guards are UX, not security. Every endpoint independently verifies the
session — no endpoint trusts a header, a query param, or a client-asserted user id.
- **Verify:** call the protected endpoint with `curl` and no cookie/token. Expect 401, not 200.
- Hidden UI ≠ protected route. Test the API directly, not the app.

### 7. Lock record access (IDOR)
Authenticated is not authorized. `GET /orders/123` must confirm order 123 belongs to the caller.
- **Verify:** log in as user A, request user B's record id. Expect 403/404, never the record.
- Prefer non-guessable ids (UUID/ULID) for user-facing resources, but never *as* the access
  control — obscurity is a speed bump, the ownership check is the wall.

### 8. Block field tampering (mass assignment)
Never spread a request body into a DB write. Whitelist the fields a user may set; `role`,
`isAdmin`, `balance`, `status`, `plan`, `verified`, `ownerId` are server-set only.
- **Verify:** POST an update including `{"role":"admin"}` and confirm the stored row is unchanged.
- Use a validated DTO/schema as the *only* path from request to persistence layer.

---

## Group C — Identity & Sessions

### 9. Secure session cookies
`httpOnly`, `secure`, `sameSite: 'lax'` (or `strict`), explicit `path`, sane `maxAge`. Never
store a session token in `localStorage` — any XSS reads it instantly.
- Rotate the session id on login and on privilege change; invalidate server-side on logout.
- **Kill *every* session on password change or reset** — not just the current one. The whole
  point of a reset is evicting an attacker who already has a live session; leaving their other
  sessions valid defeats it. Store a `sessionsValidAfter` timestamp (or token version) per user
  and reject anything issued earlier. Same on email change and MFA enrolment.
- **Verify:** log in on two browsers, change the password in one, refresh the other — expect 401.

### 10. Hash (and salt) passwords
argon2id (preferred) or bcrypt with a modern cost factor. Never MD5/SHA-family, never
reversible storage. Compare with the library's constant-time verify.
- **Salting is automatic — do not hand-roll it.** argon2id and bcrypt generate a unique random
  salt per password and embed it in the output string (`$argon2id$v=19$m=...$<salt>$<hash>`),
  so you store one value and no salt column. A homemade `sha256(salt + password)` is the
  anti-pattern: the salt kills rainbow tables but SHA is *built to be fast*, so a GPU still
  grinds billions of guesses/sec. The real control is the **work factor** (memory + time cost),
  which is what argon2/bcrypt add and a fast hash cannot.
- Exception: `scrypt`/`pbkdf2` from `node:crypto` do **not** embed a salt — generate 16+ random
  bytes yourself and store them. Both are acceptable KDFs, but they hand you that footgun.
- Optional, stacks on top: a **pepper** — a secret app-wide value from the secret manager, never
  in the DB (argon2's `secret` option). Salt is per-user and public; pepper is global and secret,
  so a DB dump alone can't be cracked. Cost is rotation: version the key and rehash on next login.
- Password reset tokens: random, hashed at rest, single-use, short expiry.
- **Verify:** read a row from the users table — the stored value must be an argon2/bcrypt digest
  with its salt segment present, not a bare 64-char hex string.

### 11. Rate limit login
Throttle authentication, password reset, OTP, and any send-an-email/SMS endpoint. Limit per
IP **and** per account, so one attacker can't spray many accounts and one target can't be locked
out by an attacker. Add backoff or lockout after repeated failures.
- Return identical responses/timing for "no such user" and "wrong password" — no enumeration.
  This applies to signup and password-reset too: "if that account exists, we sent an email"
  is the only safe response, and it must take the same time either way.
- **Prefer progressive backoff + CAPTCHA over hard account lockout.** Lockout-after-N-failures
  is itself a DoS: anyone who knows your email can lock you out on demand. If you do lock, give
  a self-service unlock (emailed link) and never lock an admin account out of its only path in.
- **Verify:** loop 20 bad logins; expect 429 before the loop ends.

### 12. Add bot protection
CAPTCHA/Turnstile on signup, login, and public forms. Verify the token **server-side** — a
client-side widget alone stops nothing.
- Pair with an email-verification gate before an account can do anything meaningful.

### 13. Verify JWTs properly
A JWT is signed, not encrypted — anyone can read the payload, so never put a secret in it and
never trust a claim you did not verify.
- **Pin the algorithm server-side.** Reject `alg: none` and reject a token whose header asks
  for a different family than you issued. The classic break is handing an RS256 verifier an
  HS256 token signed with the *public* key as the HMAC secret — the library accepts it and the
  attacker mints any identity they like.
- Verify `exp`, and `iss`/`aud` where you set them. An unexpiring token is a permanent credential.
- The signing secret comes from the secret manager (control 1), is at least 256 bits, and is
  not the string `secret`, the project name, or a value that ever reached the client bundle.
- **Have a revocation story.** Signature validity is not authorization: a stateless JWT stays
  valid until it expires, including after logout, a password reset, or a role downgrade. Either
  keep the TTL short with a refresh token you *can* revoke, or check the `sessionsValidAfter`
  stamp from control 9 on every request. Pick one deliberately.
- **Verify:** take a valid token, re-sign it with `alg: none`, and re-sign it with HS256 using
  your public key as the secret. Both must 401. Then log out and replay the original — if it
  still works, you have no revocation.

### 14. Configure OAuth correctly
Most OAuth breaks are configuration, not cryptography.
- **`redirect_uri` is an exact-match allowlist.** No wildcards, no subdomain patterns, no
  open-redirect hop — anything looser hands the authorization code to the attacker's host.
- **`state`** is random per-attempt, bound to the session, and checked on return; without it
  the callback is CSRF-able into linking the victim's account to the attacker's identity.
- **PKCE** for any public client (SPA, mobile, desktop). Treat it as default, not optional.
- Request the **minimum scopes**, and store the resulting refresh tokens encrypted (control 5).
- Trust the token endpoint's response, never an id claim the browser hands you. Verify the
  issuer's signature; match the account on the provider's stable subject id, and only treat an
  email as identity if the provider marks it verified — otherwise it is an account-takeover path.
- **Verify:** replay the callback with a foreign `redirect_uri` and with a stale/absent `state`.
  Both must fail closed.

---

## Group D — Input & Output

### 15. Parameterize queries
Parameterized queries or the ORM's query builder, always. Never build SQL by string
concatenation or template literal with user input — including `ORDER BY`/table names, which
can't be parameterized and must be whitelisted against a fixed allowlist.
- **Verify:** grep for raw-SQL escapes: `$queryRawUnsafe`, `query(` with backticks, `.raw(`.
- **NoSQL takes operator injection instead.** Mongo and friends have no string to escape; the
  attack is a *type* — a login body sending `{"password": {"$ne": null}}` or `{"$gt": ""}`
  where a string was expected turns the filter into "match anything". Parameterizing does not
  help, because the object *is* the query.
  - Coerce to the expected primitive before it reaches the driver, and reject keys beginning
    with `$` or containing `.` in any user-supplied object. Schema validation (control 16) with
    `strict`/unknown-key rejection is what actually closes this.
  - The same shape hits `$where`, `mapReduce`, and any operator that evaluates JS — don't
    expose them to user input at all.
  - **Verify:** POST `{"email":"a@b.c","password":{"$ne":null}}` to your login route. Expect
    a 400, never a session.

### 16. Validate all input
Schema-validate every request body, query param, and path param at the boundary
(zod / class-validator / pydantic). Whitelist shape and type, enforce length caps, reject
unknown keys. Validate on the server even when the client already validated.
- **Validate on input, escape on output — do not "sanitize before storing".** Sanitizing at
  write time is context-blind (it can't know the value will later land in HTML vs SQL vs a shell
  arg vs JSON) and it corrupts legitimate data permanently — `O'Brien`, `<3`, and pasted code
  all get mangled. Store the raw value; encode at the point of use, where the context is known.
  The exception is *normalization* (trim, lowercase an email, strip a BOM), which is fine.
- **Verify:** send a malformed and an oversized payload; expect 400, not a 500 stack trace.

### 17. Escape user content
Render user content as text. React/Vue/Svelte escape by default — the risk is where you opt out:
`dangerouslySetInnerHTML`, `v-html`, `innerHTML`, unsanitized markdown. Sanitize with DOMPurify
if HTML must be rendered. Never put user input into `href="javascript:"` or an inline event handler.
- **Verify:** grep for the escape hatches above; each hit needs a sanitizer in the same path.
- Set a Content-Security-Policy as defense in depth (see 20).

### 18. Restrict file uploads
Enforce max size, an allowlist of MIME types validated from magic bytes (not the client-sent
`Content-Type` or the extension), and a server-generated random filename. Store outside the web
root or in object storage with private ACLs and signed URLs. Never serve uploads from a path
that can execute.
- **Verify:** try uploading a `.svg` and a renamed `.php`/`.js`; both must be rejected or
  neutralized (SVG carries script).

### 19. Trim API responses
Serialize explicitly — return the fields the client needs, never the raw DB row. Password
hashes, tokens, internal ids, other users' emails, and soft-delete flags must not leak through
a `SELECT *` → `res.json(row)` path.
- **Verify:** read the actual JSON of your main endpoints and account for every field.
- Same rule for errors: log the stack server-side, return a generic message and a correlation id.

---

## Group E — Transport & Supply Chain

### 20. Add security headers
`Content-Security-Policy` (no `unsafe-inline`/`unsafe-eval` if reachable),
`Strict-Transport-Security` (with a long max-age), `X-Content-Type-Options: nosniff`,
`X-Frame-Options: DENY` or CSP `frame-ancestors`, `Referrer-Policy`, and a restrictive
`Permissions-Policy`. Use helmet or the framework's headers config.
- CORS is part of this: an explicit origin allowlist. `origin: '*'` with `credentials: true`
  is invalid and dangerous — never reflect the request origin unchecked.
- **Verify:** `curl -sI https://yourdomain | grep -iE "content-security|strict-transport|x-frame|x-content-type|referrer"`

### 21. Force HTTPS
Redirect all HTTP → HTTPS, enable HSTS, and make sure no mixed content or plaintext internal
call remains. Cookies carry `secure`. Certificate renewal must be automated **and monitored** —
an expired cert is an outage.
- **Verify:** `curl -sI http://yourdomain` returns a 301 to `https://`.

### 22. Scan dependencies
CI runs `npm audit` (or `pnpm audit` / `pip-audit` / `cargo audit`) and a SAST/secret scan on
every PR, and the pipeline **fails** on high/critical — a scan whose result nobody reads is
theater. Keep Dependabot (or equivalent) on, review its PRs rather than auto-merging blindly,
and pin/lockfile everything including CI action versions by SHA.
- **Verify:** open the most recent CI run and read the security job's output.

### 23. Vet the package itself, not just its CVEs
A vulnerability scanner reads a database of *known flaws in real packages*. It says nothing
about a package that is malicious by design and three days old — a different failure needing a
different check.
- **Confirm the name before installing.** Typosquats ride on a character (`crossenv`,
  `lodahs`), and AI-suggested dependencies routinely invent plausible names that squatters then
  register precisely because models keep recommending them. Never install a package because it
  appeared in generated code — look it up: does it exist, is it the one the docs name, what is
  its download count and repository, when was it published?
- Lockfile committed, installs run from it (`npm ci`, not `npm install`). `--ignore-scripts`
  where the toolchain tolerates it — install scripts are the usual payload.
- Read what a dependency bump *adds transitively*; a one-line version bump can pull in a new
  maintainer's first release.
- Prefer fewer, larger, well-maintained dependencies over many tiny ones. Every package is a
  person who can be compromised.
- **Verify:** on any PR that touches the lockfile, diff it and account for every added package
  by name. An unexplained new transitive dependency blocks the merge.

---

## Group F — Request Surface (24–28; any app serving HTTP)

### 24. Add CSRF protection
If you authenticate with **cookies**, you need CSRF defense — the browser attaches the cookie to
a cross-site request automatically, so any other site can trigger authenticated actions.
- `sameSite: 'lax'` blocks the classic form-POST attack and is the baseline; `strict` where UX allows.
- Add a token (synchronizer or double-submit) for any state-changing route, especially if you
  need `sameSite: 'none'`. Most frameworks ship one (`csurf`, Django/Rails/Laravel built-ins).
- **Not needed** for a pure `Authorization: Bearer` API — the header isn't sent automatically.
  Cookie-auth *is* the trigger. Know which one you're running; hybrids need it.
- **Verify:** POST to a state-changing route from a different origin with a valid session cookie
  and no token. Expect 403.

### 25. Limit request size
Set an explicit body cap (`express.json({ limit: '100kb' })`, `client_max_body_size` in nginx,
framework equivalent) and a separate, larger cap on upload routes only. Without one, a single
large POST can exhaust memory.
- Cap it at every layer that has one — proxy *and* app — so the proxy rejects before your app allocates.
- Also bound: JSON nesting depth, array lengths in validated schemas, URL/header length, and
  request timeouts. Unbounded array input is a quiet DoS.
- **Verify:** `curl -X POST -H 'Content-Type: application/json' --data-binary @10mb.json <url>`
  → expect 413, not a hang or an OOM.

### 26. Rate limit the whole API, not just login
Control 11 throttles credential attacks; this one throttles everything else. Any endpoint that
is unmetered is a free resource for whoever finds it — scraping your catalogue, enumerating
ids, burning your email quota, or simply costing you the bill.
- Default-deny in shape: a global per-IP ceiling, a tighter per-authenticated-user budget, and
  named tighter limits on the expensive routes — search, export, report generation, file
  processing, anything calling a paid third party (AI has its own control, 30).
- **Key the limit on something the caller cannot trivially rotate.** Per-IP alone collapses
  against a botnet and punishes shared NATs; per-user is the meaningful budget once
  authenticated. Do both.
- Enforce it in shared infrastructure (gateway, edge, middleware), not per-route by hand —
  a per-route limiter protects the routes someone remembered.
- Return `429` with `Retry-After`. Don't silently drop, and don't let the limiter itself become
  the memory leak — bounded store, TTL'd keys.
- **Verify:** loop 200 requests at an ordinary read endpoint and at your most expensive one.
  Both must start returning 429, and the limit must survive a process restart if it is
  advertised as durable.

### 27. Close the unintended surface
Everything reachable that you didn't mean to publish:
- Directory listing **off** (nginx `autoindex off;` — it's the default, confirm anyway).
- No default/dev admin routes in prod: framework debug panels, `/debug`, `/__health` with
  internals, Swagger/GraphQL Playground, Adminer/pgAdmin, seeded default credentials.
- GraphQL: disable introspection in prod and cap query depth/complexity.
- Nothing sensitive served statically: `.git/`, `.env`, `.DS_Store`, backups, source maps.
- Strip or genericize the `Server` / `X-Powered-By` version banner.
- **Verify:** `for p in .git/config .env .DS_Store swagger graphql admin; do curl -so /dev/null -w "%{http_code} $p\n" https://yourdomain/$p; done`
  — everything must be 404/403.

### 28. Lock down non-production environments
Staging, preview, and branch deploys are the same code with weaker discipline, and they are
routinely the softest way in — often reachable at a guessable URL with no auth in front of them.
- **A non-prod environment must not hold production data.** If you seeded it from a prod dump,
  it is a production database with a staging password: either anonymize on import, or protect
  it exactly as strictly as prod. There is no third option.
- Put auth, an IP allowlist, or platform protection in front of every preview deploy. Serve
  `X-Robots-Tag: noindex` and a `robots.txt` deny so it never reaches a search index.
- Separate credentials per environment — separate database, separate API keys, provider test
  mode for payments. A staging key that works in prod means staging *is* prod.
- Debug tooling and verbose errors may live here; that is exactly why the environment must not
  be public.
- **Verify:** open the preview URL in a private window. Expect an auth wall, not the app. Then
  confirm its `DATABASE_URL` and API keys differ from production, and that
  `curl -sI <preview>/ | grep -i x-robots-tag` shows `noindex`.

## Group G — AI Features (29–30; only if the app calls an LLM)

### 29. Treat model output as untrusted input
Prompt injection is not fully solvable by prompt wording — "ignore previous instructions"
defenses lose to a determined attacker. Architect so a successful injection is *survivable*.
- **The model never holds authority.** Every tool call or DB write it triggers re-checks the
  *user's* permissions server-side. An injected instruction must not be able to reach data the
  user couldn't reach directly.
- Keep untrusted content (user text, scraped pages, uploaded docs, emails) clearly delimited
  from instructions, and never concatenate it into a privileged system prompt.
- Model output that reaches a browser is user content: escape it (control 17). Never `eval` it,
  never pass it to a shell, never interpolate it into SQL.
- Cap the blast radius: allowlist the tools available per context, require confirmation for
  destructive or outbound actions, and log every tool call with the triggering input.
- **Verify:** submit a document containing an instruction to reveal the system prompt / call an
  admin tool, and confirm nothing privileged happens.

### 30. Cap AI usage and cost
LLM endpoints are metered, so abuse is a direct financial DoS.
- Per-user and per-org quotas (requests *and* tokens), enforced server-side and reset on a window.
- Cap `max_tokens` and input length per call; reject oversized context before it's billed.
- Provider-side spend limits and a billing alert as the backstop — the account is the last line.
- Require auth on anything that hits a model. A public unmetered AI endpoint will be drained.
- **Verify:** exhaust a test user's quota and confirm 429 with no further provider calls billed.

---

## Group H — Injection surfaces beyond SQL (31–34)

Same root cause as control 15 — user input crossing into an interpreter — but four different
interpreters, each with its own escape. A stack can be immune to SQL injection and wide open here.

### 31. Block path traversal
Any route that takes a filename, a key, a template name, or a download id can be walked out of
its directory with `../`.
- **Never concatenate user input into a path.** Resolve the candidate and assert the result is
  still inside the intended root before opening it — `path.resolve(root, input)` then check it
  `startsWith(root + path.sep)`. Rejecting the literal `..` is not enough: `%2e%2e%2f`,
  `....//`, UTF-8 overlongs, and a Windows `\\` all get past a naive filter, and normalisation
  order is where hand-rolled checks break.
- Better: don't accept paths at all. Take an opaque id, look the real path up in the database.
- An absolute path is traversal too — `path.join(root, "/etc/passwd")` escapes on most platforms.
- **Verify:** against every file-serving and download route, request `../../../../etc/passwd`
  and its URL-encoded and double-encoded forms. Expect 400/404, never file contents.

### 32. Prevent SSRF
Anywhere your **server** fetches a URL the **user** supplied, the attacker is choosing what your
infrastructure connects to — from inside your network. Webhook URLs, avatar-by-URL, link
previews, PDF/image fetchers, "import from URL", and LLM tool calls are all this.
- Allowlist by scheme and host. `http`/`https` only — block `file://`, `gopher://`, `ftp://`,
  and everything else outright.
- Block the private ranges: loopback (`127.0.0.0/8`, `::1`), RFC1918 (`10/8`, `172.16/12`,
  `192.168/16`), link-local `169.254.0.0/16`, and `metadata.google.internal`. The cloud
  metadata endpoint `169.254.169.254` hands out IAM credentials to anything that asks.
- **Resolve the hostname yourself, check the resolved IP, then connect to that IP** — otherwise
  DNS rebinding passes your check and connects somewhere else a moment later.
- **Disable redirect following**, or re-run the whole check on every hop. A permitted host that
  302s to the metadata IP defeats a first-hop-only check.
- Don't return the raw upstream response body or its error text — a blind SSRF becomes readable
  otherwise. Set a short timeout and a response size cap.
- **Verify:** submit `http://169.254.169.254/latest/meta-data/`, `http://localhost:5432`, and a
  public URL that redirects to the metadata IP. All three must be refused.

### 33. Never build shell commands from user input
The prize for the attacker is direct code execution, so this outranks almost everything else.
- Use the **array form** with a fixed binary — `spawn("convert", [inputPath, outputPath])` —
  never a single interpolated string, and never `shell: true`. With no shell, there is no
  metacharacter to escape.
- Prefer a library over shelling out at all (image processing, archives, PDF).
- If a value must reach an argument, validate it against a strict allowlist pattern first;
  quoting is not a defence you should be relying on.
- Filenames count as user input. So does model output (control 29).
- **Verify:** `grep -rnE "exec\(|execSync|shell: *true|os\.system|subprocess.*shell=True|Runtime\.getRuntime" src/`
  — every hit must be a fixed command with no interpolated user value.

### 34. Don't deserialise untrusted data into objects
Formats that reconstruct *typed objects* execute code as a side effect of parsing. Feeding one
attacker-controlled bytes is remote code execution, before any of your logic runs.
- The dangerous ones: Python `pickle`/`yaml.load` without `SafeLoader`, PHP `unserialize`,
  Java native serialization, Ruby `Marshal`, .NET `BinaryFormatter`, and any "auto-detect the
  type from the payload" convenience.
- Use **JSON plus a schema** (control 16). JSON has no type-instantiation semantics — that is
  precisely why it is safe here.
- Session and cache payloads count. A signed cookie holding a serialized object is this bug
  with an extra step, and the signature only helps while the key is secret.
- **Verify:** `grep -rnE "pickle\.loads|yaml\.load\(|unserialize\(|Marshal\.load|BinaryFormatter" .`
  — each hit must be reading data your own server produced and signed, never a request body.

---

## Group I — Operations (35–44; verify before launch, not after the incident)

These are the controls that determine whether you can *detect* a breach and *recover* from one.
They were previously listed here as aspirations; they are controls, and they have checks.

### 35. Keep an audit trail
Record authentication events (success and failure), privilege and role changes, password and
email changes, admin actions, and data exports. Each entry: timestamp, actor id, source IP,
what changed.
- Append-only, and retained long enough to investigate — a breach is typically found weeks late.
- Admins must not be able to silently erase their own trail.
- **Verify:** perform a role change and an admin action, then find both in the log with actor
  and IP present.

### 36. Keep secrets out of logs — and logs out of public reach
Two failures, one control. Logs are the most common place a well-protected secret leaks.
- Never log: passwords, tokens, session ids, API keys, full card numbers, and full PII. Redact
  `Authorization` headers and cookies at the logger, not at each call site. Beware the whole
  request object — `console.log(req)` prints headers, and error reporters serialize context.
- Errors go to the log with a stack and a correlation id; the *user* gets a generic message
  (control 19).
- The log sink is not public: no world-readable log file under the web root, no unauthenticated
  log dashboard, no verbose logs in a client bundle.
- **Verify:** `grep -riE "authorization|bearer |password|sk_live|session=" <recent log>` returns
  nothing, and fetching your log/monitoring dashboard signed-out returns 401/403.

### 37. Back up, and prove the restore
An untested backup is a guess. The failure everyone discovers too late is a backup job that has
been writing zero-byte files for months.
- Automated, scheduled, **off-box** (a snapshot in the same account someone just compromised is
  not a backup), and encrypted at rest.
- Retention long enough to survive slow corruption, not just yesterday's mistake.
- Know your RPO/RTO — how much data you can lose, how long recovery takes — before you need them.
- **Verify:** restore the latest backup into a scratch database and read real rows out of it.
  Write down the date you last did this; if you cannot name it, the control is FAIL.

### 38. Monitor and alert
Logging without alerting means the evidence exists and nobody reads it.
- Alert a human on: authentication-failure spikes, 5xx spikes, new admin/role grants, unusual
  data-export volume, and provider spend anomalies.
- Uptime and certificate-expiry monitoring (control 21) belong here too.
- Tune it. An alert channel everyone mutes is worse than none, because it looks like coverage.
- **Verify:** trigger a test alert end to end and confirm it reaches a person, not just a
  dashboard nobody has open.

### 39. Run everything least-privilege
Assume any single component will be compromised, and bound what that costs you.
- Application database user has DML only — no `DROP`, no schema changes, no superuser. Migrations
  run as a separate, restricted-access role.
- Cloud IAM roles scoped per service; no long-lived root or wildcard `*` policies. Storage
  buckets private by default with signed URLs (control 18).
- Firewall default-deny; the database port is not reachable from the internet. SSH by key only.
- Rotate credentials on a schedule, and know how to rotate all of them quickly (see below).
- **Verify:** from an off-network machine, attempt a direct database connection and an anonymous
  bucket list. Both must fail. Then confirm the app's DB user cannot `DROP TABLE`.

### 40. Isolate tenants
If one customer's users can reach another customer's data, nothing else in this document matters.
- The tenant filter is applied **centrally** — in RLS, a base query scope, or a repository layer
  — never re-typed per endpoint, where one omission exposes everyone.
- The tenant id comes from the session, never from a request parameter the client can change.
- Background jobs, exports, search indexes, caches, and file storage paths are all tenant-scoped
  too. Cache keys missing a tenant id are a quiet cross-tenant leak.
- **Verify:** an automated test that authenticates as tenant A and requests tenant B's records
  across your main endpoints, expecting zero rows every time. This test should exist in CI.

### 41. Verify webhooks
An unauthenticated public endpoint that mutates state on request is what an unverified webhook
handler is — anyone who learns the URL can post to it.
- Verify the provider's signature over the **raw** body, before parsing (frameworks that
  auto-parse JSON will break the signature — capture the raw buffer on that route).
- Compare with a constant-time function. Reject stale timestamps (a few minutes' window) and
  replayed event ids.
- Make the handler **idempotent** — providers legitimately retry, so processing twice must not
  charge twice or double-provision.
- **Verify:** replay a captured webhook and confirm it is rejected; POST an unsigned body and
  confirm 400; deliver the same event id twice and confirm one effect.

### 42. Keep payment authority on the server
The client is a price-editing UI unless you decide otherwise.
- **Look the amount up server-side from your own catalogue by product id.** Never accept an
  amount, currency, quantity, or discount from the request. Re-validate coupons — expiry, usage
  limits, eligibility — at charge time, not at display time.
- Raw card data never touches your servers: use the provider's hosted flow so PCI scope stays
  with them.
- **The signed webhook is the source of truth for "paid"** — not a browser redirect to
  `/success`, which the user can simply navigate to. Provision entitlements from the webhook.
- Verify the amount actually captured matches what you intended before granting anything.
- **Verify:** intercept the checkout request, change the amount and the coupon, and confirm the
  charge is unchanged. Then hit `/success` directly without paying and confirm nothing is granted.

### 43. Make the security gate unbypassable
Every control enforced in CI assumes nobody can route around CI. If a commit can reach the
default branch without passing the pipeline, the pipeline is advisory — and controls 22 and 23
in particular become decorative, because they run on pull requests that an urgent fix will
simply skip.
- **Protect the default branch at the forge, not by convention.** Require the security jobs as
  status checks, require a pull request before merging, and block force-pushes and deletions.
  A rule that lives in someone's memory is not a control.
- **Include administrators.** The bypass that gets used is the one belonging to the person
  under time pressure, which on a small team is the owner. A protection rule that exempts
  admins protects the repository from everyone who could not have merged anyway.
- **A required check that nothing reports blocks everything.** Configure the protection and
  the workflow together: a status check is required by *name*, so a job renamed or never run
  leaves every pull request waiting on a result that will never arrive. With admin enforcement
  on, that state cannot be cleared by merging past it. Add the workflow first, let it report
  once, then require it.
- **Pin what the pipeline runs.** Third-party actions by commit SHA, not tag — a tag is mutable
  by whoever owns the action, so an unpinned action is a standing write-access grant to a
  stranger. Restrict who can edit workflow files, and treat a PR that changes the gate as a
  security review of the gate.
- **Least privilege for the pipeline itself.** Default the workflow token to read-only and
  grant writes per job. A build step that can push to the default branch has undone this
  control. CI secrets must not be exposed to pull requests from forks.
- **Verify:** from a clean clone, commit directly to the default branch and push — expect a
  rejection. Then read the protection back from the API rather than the settings page:
  `gh api repos/:owner/:repo/branches/main/protection --jq '{checks: .required_status_checks.contexts, admins: .enforce_admins.enabled, force: .allow_force_pushes.enabled}'`
  A `404` means there is no protection at all, which is the most common finding. Confirm each
  listed check name matches a job that actually runs.

### 44. Vet what you install into your own agent
Your coding agent runs with your permissions: your filesystem, your credentials, your repo. A
skill, plugin, or MCP server is not a document it reads, it is an instruction it follows — and
the files that ship in the bundle are a different object from the text that eventually executes.
- **A skill that fetches instructions from a URL is remote code you have not reviewed.** The
  bundle you audited and the text the agent obeys are separated by an HTTP request, so whoever
  controls that URL can change the second after you approved the first. Static scanning cannot
  catch this by construction. Researchers at AIR demonstrated it end to end in 2026: a skill
  passed Cisco, NVIDIA and marketplace scanners while its external link served genuine vendor
  documentation, then served instructions to download and run a script once adoption was up.
  (Install counts in that write-up are self-reported and unverified; the mechanism is not.)
- **Check the publisher and the destination, not the description.** Does the vendor actually
  publish this, from their own domain? A convincing name plus a plausible docs link is the whole
  attack. Anthropic's own guidance is to use skills only from sources you created or trust, and
  it names external-URL fetches as the particular risk.
- **Pin and vendor what you keep.** Copy the skill into the repo, review it there, update
  deliberately. A skill that changed maintainer is a new skill and needs a new review.
- **Least privilege for the agent itself.** Don't run it in a directory whose environment holds
  production credentials, and prefer per-project scope over a global install. Surface matters:
  Claude Code skills have the same network access as any other program on the machine, while
  API-side skills run sandboxed without network.
- **Verify:** inventory every URL reachable from an installed skill, plugin, or MCP server as well
  as MCP and plugin executable sources (including `command` and `args` entries such as `npx`, `uvx`,
  and `pipx`). Cover all three artefact types, not just skills:
  `bash ci/scripts/vet-agent-installs.sh`
  The script prints HTTP(S) URLs with userinfo and credential-bearing query/fragment
  parameters (including `api_key`, `client_secret`, `X-Amz-Signature`) redacted, followed
  by each discovered MCP/plugin executable invocation with credential argument values
  redacted. It handles multiline JSON `args` arrays. Copy `ci/scripts/vet-agent-installs.sh`
  from this repo if you are running the check outside of a project that includes it.
  Every host must resolve to either an immutable reference (a pinned commit or content digest
  that cannot change under you) or a copy you reviewed and vendored. Every discovered executable
  source must reference an integrity-locked package or a reviewed vendored executable. **A vendor-owned domain is
  not an exemption.** The failure mode is that fetched content or executable packages change after review, and a
  legitimate domain or package registry can be compromised, expire, or change hands. Anything that is neither pinned
  nor vendored is the finding: remove it, or vendor a reviewed copy and drop the fetch.

---

## Beyond the forty-four (add when the project reaches them)

- **Account deletion / data export** — required by GDPR-style regimes if you have EU/UK users,
  and the retention promise must match what the code actually deletes. See `legal-compliance`.
- **Incident runbook** — written before you need it: how to rotate every credential, revoke every
  session, take the app offline, and who is called. Practise it once.
- **MFA / step-up auth** — at minimum for admin accounts, before you have many users to protect.
- **Formal pentest and a disclosure channel** — a `security.txt` and a monitored address, so a
  researcher can reach you instead of disclosing publicly.

## Reporting rules

When you finish an audit:
- Report per control with evidence (the command run, the response seen).
- Order findings by exploitability — a public admin endpoint outranks a missing header.
- State clearly what you did **not** check and why.
- Do not claim a system is "secure". Claim which controls pass, which fail, and what's unverified.
