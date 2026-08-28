// Control 3 — service-role key referenced from a client path.
export const admin = createClient(url, process.env.SUPABASE_SERVICE_ROLE_KEY);
export const alsoAdmin = config.SERVICE_ROLE_KEY;

// Control 3/1 — a live-looking key as a literal. Deliberately shaped so it does not
// look like a real Stripe key to a secret scanner: this file is a fixture, and a repo
// that ships a secret-scanning gate must not fail its own gate.
export const stripeKey = "sk_live_EXAMPLE_FIXTURE_NOT_A_REAL_KEY";
