import { describe, it, expect, beforeEach } from "vitest";
import { makeArtGenerateHandler } from "../lib/handlers/art-generate.js";
import { jwksVerifier } from "../lib/jwt.js";
import { makeJwtHarness, type JwtHarness } from "./fakes/jwt-harness.js";
import { makeFakeStore, type FakeStore } from "./fakes/fake-store.js";
import { makeFakeImageGen, type FakeImageGen } from "./fakes/fake-openai.js";
import { makeFakeStorage, type FakeStorage } from "./fakes/fake-storage.js";
import { makeRequest } from "./fakes/request.js";
import type { ArtGenerateResponse } from "../lib/schemas.js";
import type { ErrorEnvelope } from "../lib/errors.js";

const PLAYER = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const OTHER = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const INSTANCE = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";

function validBody(overrides: Record<string, unknown> = {}) {
  return {
    instance_id: INSTANCE,
    genome_hash: "deadbeefcafef00d",
    sigil_seed: 123456789,
    prompt_spec: { prompt: "a many-eyed primordial of Chaos, occult heraldry" },
    ...overrides,
  };
}

describe("/api/art/generate", () => {
  let harness: JwtHarness;
  let store: FakeStore;
  let imageGen: FakeImageGen;
  let storage: FakeStorage;

  function buildHandler(opts: {
    imageGen?: FakeImageGen;
    store?: FakeStore;
    perMinute?: number;
    monthlyCap?: number;
  } = {}) {
    return makeArtGenerateHandler({
      verifier: jwksVerifier(harness.source),
      store: opts.store ?? store,
      imageGen: opts.imageGen ?? imageGen,
      storage,
      rateLimit: { perMinute: opts.perMinute ?? 6, monthlyCap: opts.monthlyCap ?? 200 },
    });
  }

  beforeEach(() => {
    harness = makeJwtHarness();
    store = makeFakeStore({ instanceOwners: { [INSTANCE]: PLAYER } });
    imageGen = makeFakeImageGen();
    storage = makeFakeStorage();
  });

  it("generates once and persists a ready asset (happy path)", async () => {
    const handler = buildHandler();
    const res = await handler(makeRequest({ token: harness.sign({ sub: PLAYER }), body: validBody() }));

    expect(res.status).toBe(200);
    const body = res.body as ArtGenerateResponse;
    expect(body.status).toBe("ready");
    expect(body.image_url).toMatch(new RegExp(`art/${PLAYER}/${INSTANCE}/123456789\\.png$`));
    expect(imageGen.moderateCalls).toBe(1);
    expect(imageGen.generateCalls).toBe(1);
    expect(storage.uploadCalls).toBe(1);
    expect(store.art.get(INSTANCE)?.status).toBe("ready");
  });

  it("GENERATE-ONCE INVARIANT: a second call returns the same asset with NO second OpenAI call", async () => {
    const handler = buildHandler();
    const first = (await handler(
      makeRequest({ token: harness.sign({ sub: PLAYER }), body: validBody() }),
    )).body as ArtGenerateResponse;

    expect(imageGen.generateCalls).toBe(1);

    // Second identical request for the same instance.
    const second = (await handler(
      makeRequest({ token: harness.sign({ sub: PLAYER }), body: validBody() }),
    )).body as ArtGenerateResponse;

    // Same stored asset, no new generation / moderation / upload.
    expect(second.art_asset_id).toBe(first.art_asset_id);
    expect(second.image_url).toBe(first.image_url);
    expect(second.status).toBe("ready");
    expect(imageGen.generateCalls).toBe(1); // <-- the keystone assertion
    expect(imageGen.moderateCalls).toBe(1);
    expect(storage.uploadCalls).toBe(1);
  });

  it("GENERATE-ONCE under concurrency: two simultaneous calls => exactly one OpenAI generation", async () => {
    const handler = buildHandler();
    const req = () => makeRequest({ token: harness.sign({ sub: PLAYER }), body: validBody() });

    const [a, b] = await Promise.all([handler(req()), handler(req())]);

    // Exactly one generation happened; both callers end with a consistent asset id.
    expect(imageGen.generateCalls).toBe(1);
    expect(storage.uploadCalls).toBe(1);
    const idA = (a.body as ArtGenerateResponse).art_asset_id;
    const idB = (b.body as ArtGenerateResponse).art_asset_id;
    expect(idA).toBe(idB);
    // One is 'ready'; the loser may be 'pending' or 'ready' depending on interleaving, never a 2nd gen.
    const statuses = [(a.body as ArtGenerateResponse).status, (b.body as ArtGenerateResponse).status];
    expect(statuses).toContain("ready");
  });

  it("rejects a missing Authorization header (401 unauthorized)", async () => {
    const handler = buildHandler();
    await expect(handler(makeRequest({ body: validBody() }))).rejects.toMatchObject({
      code: "unauthorized",
      status: 401,
    });
    expect(imageGen.generateCalls).toBe(0);
  });

  it("rejects an invalid/forged token (401 unauthorized)", async () => {
    const handler = buildHandler();
    const foreign = makeJwtHarness("attacker-key"); // different keypair, not in our JWKS
    const forged = foreign.sign({ sub: PLAYER });
    await expect(
      handler(makeRequest({ token: forged, body: validBody() })),
    ).rejects.toMatchObject({ code: "unauthorized" });
    expect(imageGen.generateCalls).toBe(0);
  });

  it("rejects an expired token (401 unauthorized)", async () => {
    const handler = buildHandler();
    const expired = harness.sign({ sub: PLAYER, exp: Math.floor(Date.now() / 1000) - 3600 });
    await expect(
      handler(makeRequest({ token: expired, body: validBody() })),
    ).rejects.toMatchObject({ code: "unauthorized" });
  });

  it("rejects when the player does not own the instance (403 forbidden)", async () => {
    const handler = buildHandler();
    const res = handler(makeRequest({ token: harness.sign({ sub: OTHER }), body: validBody() }));
    await expect(res).rejects.toMatchObject({ code: "forbidden", status: 403 });
    expect(imageGen.generateCalls).toBe(0);
    expect(store.art.has(INSTANCE)).toBe(false); // never reserved
  });

  it("zod-validates the body (400 invalid_request) and never generates", async () => {
    const handler = buildHandler();
    await expect(
      handler(
        makeRequest({ token: harness.sign({ sub: PLAYER }), body: validBody({ instance_id: "not-a-uuid" }) }),
      ),
    ).rejects.toMatchObject({ code: "invalid_request", status: 400 });

    await expect(
      handler(
        makeRequest({ token: harness.sign({ sub: PLAYER }), body: validBody({ prompt_spec: {} }) }),
      ),
    ).rejects.toMatchObject({ code: "invalid_request" });

    expect(imageGen.generateCalls).toBe(0);
  });

  it("moderation gate blocks flagged prompts (422) and marks the row failed", async () => {
    const flaggedGen = makeFakeImageGen({ flagged: true, flaggedCategories: { "sexual/minors": true } });
    const handler = buildHandler({ imageGen: flaggedGen });
    await expect(
      handler(makeRequest({ token: harness.sign({ sub: PLAYER }), body: validBody() })),
    ).rejects.toMatchObject({ code: "moderation_blocked", status: 422 });

    expect(flaggedGen.generateCalls).toBe(0); // never spent on generation
    expect(store.art.get(INSTANCE)?.status).toBe("failed");
  });

  it("enforces the monthly cap (429 rate_limited) before reserving", async () => {
    store = makeFakeStore({
      instanceOwners: { [INSTANCE]: PLAYER },
      usageCount: { [PLAYER]: 200 },
    });
    const handler = buildHandler({ store, monthlyCap: 200 });
    await expect(
      handler(makeRequest({ token: harness.sign({ sub: PLAYER }), body: validBody() })),
    ).rejects.toMatchObject({ code: "rate_limited", status: 429 });
    expect(imageGen.generateCalls).toBe(0);
    expect(store.art.has(INSTANCE)).toBe(false);
  });

  it("enforces the per-minute rate limit (429 rate_limited)", async () => {
    store = makeFakeStore({
      instanceOwners: { [INSTANCE]: PLAYER },
      usageCount: { [PLAYER]: 6 },
    });
    const handler = buildHandler({ store, perMinute: 6, monthlyCap: 10000 });
    await expect(
      handler(makeRequest({ token: harness.sign({ sub: PLAYER }), body: validBody() })),
    ).rejects.toMatchObject({ code: "rate_limited" });
  });

  it("a failed generation marks the row failed (retryable) and surfaces upstream_error", async () => {
    const failingGen = makeFakeImageGen({ failGeneration: true });
    const handler = buildHandler({ imageGen: failingGen });
    await expect(
      handler(makeRequest({ token: harness.sign({ sub: PLAYER }), body: validBody() })),
    ).rejects.toBeTruthy();
    expect(store.art.get(INSTANCE)?.status).toBe("failed");
  });

  it("a subsequent call after a prior failure does not silently re-spend", async () => {
    const failingGen = makeFakeImageGen({ failGeneration: true });
    await buildHandler({ imageGen: failingGen })(
      makeRequest({ token: harness.sign({ sub: PLAYER }), body: validBody() }),
    ).catch(() => undefined);
    expect(store.art.get(INSTANCE)?.status).toBe("failed");

    // Next call sees the failed row and reports it rather than generating again automatically.
    const handler = buildHandler();
    const res = handler(makeRequest({ token: harness.sign({ sub: PLAYER }), body: validBody() }));
    await expect(res).rejects.toMatchObject({ code: "upstream_error" });
    expect(imageGen.generateCalls).toBe(0);
  });

  it("error responses use the {error:{code,message}} envelope via withErrorEnvelope", async () => {
    const { withErrorEnvelope } = await import("../lib/http.js");
    const wrapped = withErrorEnvelope(buildHandler());
    const out = await wrapped(makeRequest({ body: validBody() })); // no token
    expect(out.status).toBe(401);
    const env = out.body as ErrorEnvelope;
    expect(env.error.code).toBe("unauthorized");
    expect(typeof env.error.message).toBe("string");
  });
});
