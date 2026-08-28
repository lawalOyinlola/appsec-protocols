// Control 3 — client gets the publishable key only.
export const supabase = createClient(url, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
export const publishable = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY;
