---
name: project-kickoff
description: The decisions and setup that must exist before the first feature commit — PRD, explicit non-goals, ICP, locked tech stack, folder structure, repo hygiene (.gitignore, README, CLAUDE.md), environment separation, error tracking, and a commit/review cadence. Load at the START of a new project, when scaffolding a repo, when a project has grown past a prototype without these, or when asked "how should I set this up". Triggers on "new project", "starting a new app", "scaffold", "set up the repo", "PRD", "product requirements", "what should I build first", "tech stack", "folder structure", "project structure", "CLAUDE.md", "README", "gitignore", "staging vs production", "error tracking", "before I start building", "vibe coding a new app".
---

# Project Kickoff

What must be true before the first feature commit. Every item here is cheap now and expensive
later — not because it is urgent, but because each one becomes *structural* the moment code
depends on it. Retrofitting a folder structure, splitting staging out of prod, or adding a
`.gitignore` after a key is committed all cost far more than doing them first.

**Every item has a verification step.** As with `security-protocols`, an item is not done until
something has been checked — a file read, a command run, a URL fetched.

## How to use this skill

- **New project** → work A through E in order. A and B are decisions; C, D, E are setup.
- **Existing project that skipped this** → run it as an audit. Write results to
  `tasks/kickoff-audit.md` (`PASS` / `FAIL` / `N/A + why`). Fix C before anything else.
- **Not applicable is a valid answer** — a weekend script needs almost none of this — but say so
  in one line rather than skipping silently.

This skill stops at the first feature commit. From there:
- **`security-protocols`** — controls 1–3 (secrets) apply the moment the repo exists, not at launch.
- **`legal-compliance`** — before signups open, not after.

Do not restate their controls here. Point at them.

---

## Group A — Decide the product (before any code)

### 1. Write a PRD, in the repo, in markdown
Not in a chat window. A file at `docs/prd.md` that the coding agent can read on every session
and that survives context loss.
- Cover: what it does, who for, the core flows, and what "done" means for v1.
- Length is not the point — a page that is actually current beats ten that are stale.
- **Verify:** the file exists, and its described flows match what you would demo. A PRD that no
  longer matches the product is worse than none, because it will be believed.

### 2. State the value, the pain, and the ICP in one paragraph each
- **Pain:** what specifically is bad today, for a named kind of person.
- **Value:** what changes for them, stated as an outcome, not a feature list.
- **ICP:** who exactly this is for. "Everyone" means no one, and it makes every subsequent
  product decision a coin flip.
- **Verify:** read the three paragraphs back and ask whether they rule anything out. If they
  describe any product in the category, they are not specific enough to be useful yet.

### 3. Write the non-goals down
**The highest-value item in this skill.** An explicit "not building this in v1" list is the only
thing that reliably prevents scope creep, and it is the item people skip.
- List the plausible-sounding features you are deliberately not building, and one clause on why.
- Include the deferred hard problems: offline mode, real-time, i18n, multi-tenancy, an admin
  panel, mobile apps. Each is cheap to defer deliberately and brutal to retrofit accidentally.
- **Verify:** the list exists in `docs/prd.md` and names at least three things a reasonable
  person would otherwise assume are in scope.

### 4. Break the PRD into tasks before building
Turn v1 into a checkable list, ordered so something demoable exists early.
- In this project that means `tasks/todo.md` — the workflow already defined in `CLAUDE.md`.
- Each task small enough to finish and verify in one sitting.
- **Verify:** the first three tasks are concrete enough to start without another decision.

---

## Group B — Decide the technical (before any code)

### 5. Lock the stack and write down why
Framework, language, database, auth, hosting, styling — chosen once and recorded, so the agent
stops re-litigating it and you stop half-migrating.
- One line of rationale each. "Because it's popular" is not one.
- Prefer boring and well-documented: the coding agent has seen far more of it, and so has every
  answer you will search for.
- **Verify:** `docs/stack.md` (or a `CLAUDE.md` section) names every choice, and the installed
  dependencies match it. A stack doc contradicted by `package.json` is a trap.

### 6. Decide the data model and the auth approach before the first table
These two are the most expensive things to change later, because everything else references them.
- Sketch the core entities and their relationships. Decide tenancy now if it is ever plausible —
  adding a tenant id to a live schema is a migration *and* an audit of every query.
- Pick the auth approach (managed provider vs. rolled) deliberately. Rolling your own means
  owning `security-protocols` 9–14 in full; a managed provider means configuring them.
- **Verify:** the entity sketch exists and every entity has an owner or tenant column where it
  needs one.

### 7. Agree the folder structure
Decide where things go once. The alternative is four conventions in one repo, each introduced by
a session that could not see the others.
- Write it into `CLAUDE.md` as a short tree with one line per directory.
- **Verify:** the tree in `CLAUDE.md` matches `ls` output. Update it when it drifts; a
  documented structure nobody follows teaches the agent the wrong pattern.

### 8. Set up the design system before the first component
Colour tokens, type scale, spacing scale, and the base primitives — button, input, card — before
feature UI exists.
- Retrofitting tokens means touching every component; establishing them first means components
  are consistent for free.
- Include dark mode in the token definition *now* if you will ever want it.
- **Verify:** build one real screen using only tokens and primitives. If it needs a hard-coded
  hex or a magic pixel value, the system has a gap — fix it before building on it.

---

## Group C — Repo hygiene (do this in the first commit)

### 9. Commit `.gitignore` first, before any env file exists
Ordering matters. Once a secret is committed it is compromised permanently, and the fix is
rotation, not deletion (`security-protocols` 2).
- Cover: `.env*` (except `.env.example`), `node_modules/`, build output, `.DS_Store`, IDE
  directories, local databases, credential files.
- Commit `.env.example` with placeholder values so the shape is documented and the real file
  never needs to be.
- **Verify:** `git status --porcelain` shows no env file, and
  `git log --all --full-history -- .env` is empty. Run both before the first push, not after.

### 10. Connect the remote and protect the default branch
- Private by default. Make it public deliberately, after `security-protocols` 1–3 pass.
- Protect `main`: no direct pushes, PRs required. Even solo — it is what makes item 14 possible.
- **Verify:** attempt a direct push to `main` and confirm it is refused.

### 11. Write the README
What it is, how to run it locally, what env vars are needed, how to run tests. Aimed at someone
with a clean machine and no context — a category that includes you in six months.
- **Verify:** follow your own README from a fresh clone. Every missing step is a bug in it.

### 12. Write `CLAUDE.md`
The instruction file the agent reads every session — stack, structure, conventions, commands,
and the constraints you keep having to repeat.
- Put in it the things you have already corrected twice. That is the signal it is missing.
- Keep it current: a stale `CLAUDE.md` actively misdirects, which is worse than an absent one.
- **Verify:** start a fresh session, ask what the stack and conventions are, and check the answer
  came from the file.

### 13. Separate environments, with separate credentials
Local, staging, and production get their own database and their own API keys — payment providers
in test mode outside prod.
- Secrets come from the environment, never a committed file (`security-protocols` 1).
- A staging key that works against production means you have one environment wearing two names.
- **Verify:** print the database host and a key prefix in each environment and confirm they
  differ. Then confirm the staging deploy is not publicly reachable (`security-protocols` 28).

---

## Group D — Instrumentation (wire before launch, not after the first incident)

### 14. Add error tracking on day one
Sentry or equivalent, in every environment, with source maps uploaded privately and release
tagging on.
- Without it, your bug reports are "it didn't work" and your evidence is gone.
- Scrub PII and tokens in the `beforeSend` hook — an error reporter serializes request context,
  which is a classic secret leak (`security-protocols` 36).
- **Verify:** throw a deliberate error in staging and find it in the dashboard, with a stack
  trace that maps to real source.

### 15. Add structured logging and one health check
- Structured (JSON) logs with a request/correlation id, so a user's report can be traced to a
  request. Log levels used consistently.
- A `/health` endpoint that reports process *and* database reachability — without leaking
  internals (`security-protocols` 27).
- **Verify:** trigger a request, then find every log line for it by correlation id alone.

### 16. Add product analytics if a decision depends on it
Only if you will act on it. Analytics nobody reads is data you are now liable for.
- If added: it collects personal data, so it is a processor to name in the privacy policy
  (`legal-compliance` 4).
- **Verify:** name the specific decision the first event will inform. If you cannot, don't add it yet.

---

## Group E — Working cadence

### 17. Commit small and often, in the user's voice
One coherent change per commit, with a message explaining *why*. Small commits are what make
`git bisect` and a clean revert possible; a 40-file "wip" commit forfeits both.
- Commit before starting anything risky, so there is a known-good point to return to.
- **Verify:** read the last ten commit messages. If you cannot tell what changed without the
  diff, they are too coarse.

### 18. Nothing merges unread
The failure mode of AI-assisted building: code accumulates that nobody has read, so nobody can
maintain it, and reviewing it later costs more than writing it would have.
- Read every diff before merge — your own included. Understanding it is the point, not approval.
- Anything touching auth, payments, data access, or user input gets the relevant
  `security-protocols` group read *before* it is written.
- `/code-review` for correctness, `/simplify` for quality — neither replaces reading it.
- **Verify:** for each of the last five merges, can you explain what changed and why? If not,
  that is technical debt already accrued, not a future risk.

---

## Reporting

Same rule as the other protocol skills: report per item with evidence, and never claim a project
is "set up properly" as a blanket. State which items pass, which fail, which are `N/A` and why,
and what you did not check.

Then name the single most expensive thing still missing — usually the non-goals list (3), the
data model decision (6), or environment separation (13) — and do that one first.
