class_name SupabaseConfigExample
extends RefCounted
## EXAMPLE ONLY. Copy to a git-ignored real config and inject values at build/runtime.
## The client ships ONLY the URL + anon key (TDD §9.2). NEVER put a service-role key or
## the OpenAI key in client/. (CI secret-scans for them.)

const SUPABASE_URL := "https://YOUR-PROJECT.supabase.co"  # or http://127.0.0.1:54321 (local)
const SUPABASE_ANON_KEY := "REPLACE_WITH_PUBLIC_ANON_KEY"  # public by design, safe under RLS

# Do NOT add: SERVICE_ROLE_KEY, OPENAI_API_KEY, or any privileged secret. Server-side only.
