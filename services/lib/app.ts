// Composition root — wires the real dependencies (env secrets, Supabase service-role client,
// OpenAI provider, Storage, JWKS verifier) into the pure handlers. Route entry files in
// `api/` call these factories. Constructed lazily + memoized so a cold start builds clients
// once. Secrets are read here from env ONLY and never returned to the client.

import { loadEnv, type ServiceEnv } from "./env.js";
import { httpJwksSource, jwksVerifier, type JwtVerifier } from "./jwt.js";
import { serviceRoleClient, supabaseStore, type GameStore } from "./store.js";
import { openAiProvider, type ImageGenProvider } from "./openai.js";
import { supabaseStorage, type StorageUploader } from "./storage.js";
import { makeArtGenerateHandler } from "./handlers/art-generate.js";
import { makeSuccessionPublishHandler } from "./handlers/succession-publish.js";
import { makeSuccessionFetchHandler } from "./handlers/succession-fetch.js";

export interface AppContext {
  readonly env: ServiceEnv;
  readonly verifier: JwtVerifier;
  readonly store: GameStore;
  readonly imageGen: ImageGenProvider;
  readonly storage: StorageUploader;
}

let cached: AppContext | null = null;

export function buildAppContext(): AppContext {
  if (cached) return cached;
  const env = loadEnv();
  const client = serviceRoleClient(env);
  const issuer = `${env.SUPABASE_URL.replace(/\/$/, "")}/auth/v1`;
  cached = {
    env,
    verifier: jwksVerifier(httpJwksSource(env.SUPABASE_URL), { issuer }),
    store: supabaseStore(client),
    imageGen: openAiProvider({ apiKey: env.OPENAI_API_KEY }),
    storage: supabaseStorage(client, env.ART_BUCKET),
  };
  return cached;
}

export function artGenerateHandler() {
  const ctx = buildAppContext();
  return makeArtGenerateHandler({
    verifier: ctx.verifier,
    store: ctx.store,
    imageGen: ctx.imageGen,
    storage: ctx.storage,
    rateLimit: {
      perMinute: ctx.env.ART_RATE_LIMIT_PER_MINUTE,
      monthlyCap: ctx.env.ART_MONTHLY_CAP,
    },
  });
}

export function successionPublishHandler() {
  const ctx = buildAppContext();
  return makeSuccessionPublishHandler({ verifier: ctx.verifier, store: ctx.store });
}

export function successionFetchHandler() {
  const ctx = buildAppContext();
  return makeSuccessionFetchHandler({ verifier: ctx.verifier, store: ctx.store });
}
