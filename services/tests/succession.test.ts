import { describe, it, expect, beforeEach } from "vitest";
import { makeSuccessionPublishHandler } from "../lib/handlers/succession-publish.js";
import { makeSuccessionFetchHandler } from "../lib/handlers/succession-fetch.js";
import { jwksVerifier } from "../lib/jwt.js";
import { makeJwtHarness, type JwtHarness } from "./fakes/jwt-harness.js";
import { makeFakeStore, type FakeStore } from "./fakes/fake-store.js";
import { makeRequest } from "./fakes/request.js";
import type { SuccessionPublishResponse, SuccessionFetchResponse } from "../lib/schemas.js";

const PLAYER = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const OTHER = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const RUN = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";

function publishBody(overrides: Record<string, unknown> = {}) {
  return {
    source_run: RUN,
    name: "Aurynth, the Unmade",
    grid: "Chaos/Thanatos",
    team: [{ species: "AD01", role: "apex" }],
    signature_moves: ["unmaking"],
    shareable: true,
    ...overrides,
  };
}

describe("/api/succession/publish", () => {
  let harness: JwtHarness;
  let store: FakeStore;

  beforeEach(() => {
    harness = makeJwtHarness();
    store = makeFakeStore({ runOwners: { [RUN]: PLAYER } });
  });

  function handler() {
    return makeSuccessionPublishHandler({ verifier: jwksVerifier(harness.source), store });
  }

  it("publishes a snapshot for a run the caller owns (200)", async () => {
    const res = await handler()(
      makeRequest({ token: harness.sign({ sub: PLAYER }), body: publishBody() }),
    );
    expect(res.status).toBe(200);
    const body = res.body as SuccessionPublishResponse;
    expect(body.snapshot.source_player).toBe(PLAYER);
    expect(body.snapshot.source_run).toBe(RUN);
    expect(body.snapshot.shareable).toBe(true);
    expect(store.snapshots.size).toBe(1);
  });

  it("rejects publishing for a run the caller does NOT own (403 forbidden)", async () => {
    await expect(
      handler()(makeRequest({ token: harness.sign({ sub: OTHER }), body: publishBody() })),
    ).rejects.toMatchObject({ code: "forbidden", status: 403 });
    expect(store.snapshots.size).toBe(0);
  });

  it("rejects a missing token (401)", async () => {
    await expect(handler()(makeRequest({ body: publishBody() }))).rejects.toMatchObject({
      code: "unauthorized",
    });
  });

  it("zod-validates the body (400)", async () => {
    await expect(
      handler()(
        makeRequest({ token: harness.sign({ sub: PLAYER }), body: publishBody({ source_run: "x" }) }),
      ),
    ).rejects.toMatchObject({ code: "invalid_request" });
  });

  it("forces source_player to the caller (cannot forge another player's authorship)", async () => {
    const res = await handler()(
      makeRequest({
        token: harness.sign({ sub: PLAYER }),
        // attacker tries to set source_player in the body; schema ignores it, handler uses sub
        body: publishBody({ source_player: OTHER }),
      }),
    );
    const body = res.body as SuccessionPublishResponse;
    expect(body.snapshot.source_player).toBe(PLAYER);
  });
});

describe("/api/succession/fetch", () => {
  let harness: JwtHarness;
  let store: FakeStore;

  beforeEach(async () => {
    harness = makeJwtHarness();
    store = makeFakeStore({ runOwners: { [RUN]: PLAYER } });
    // Seed one shareable + one private snapshot.
    await store.insertGodSnapshot({
      source_run: RUN,
      source_player: PLAYER,
      name: "Shareable God",
      grid: "Chaos",
      forces: {},
      team: [],
      signature_moves: [],
      shareable: true,
    });
    await store.insertGodSnapshot({
      source_run: RUN,
      source_player: PLAYER,
      name: "Private God",
      grid: "Order",
      forces: {},
      team: [],
      signature_moves: [],
      shareable: false,
    });
  });

  function handler() {
    return makeSuccessionFetchHandler({ verifier: jwksVerifier(harness.source), store });
  }

  it("returns the shareable pool (no params)", async () => {
    const res = await handler()(makeRequest({ method: "GET", token: harness.sign({ sub: OTHER }) }));
    expect(res.status).toBe(200);
    const body = res.body as SuccessionFetchResponse;
    expect(body.snapshots).toHaveLength(1);
    expect(body.snapshots[0]!.shareable).toBe(true);
  });

  it("fetches a shareable snapshot by id for a non-owner", async () => {
    const shareableId = [...store.snapshots.values()].find((s) => s.shareable)!.id;
    const res = await handler()(
      makeRequest({ method: "GET", token: harness.sign({ sub: OTHER }), query: { id: shareableId } }),
    );
    const body = res.body as SuccessionFetchResponse;
    expect(body.snapshots[0]!.id).toBe(shareableId);
  });

  it("does NOT leak a private snapshot to a non-owner (404, honors shareable/RLS)", async () => {
    const privateId = [...store.snapshots.values()].find((s) => !s.shareable)!.id;
    await expect(
      handler()(
        makeRequest({ method: "GET", token: harness.sign({ sub: OTHER }), query: { id: privateId } }),
      ),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("returns a private snapshot to its OWNER by id", async () => {
    const privateId = [...store.snapshots.values()].find((s) => !s.shareable)!.id;
    const res = await handler()(
      makeRequest({ method: "GET", token: harness.sign({ sub: PLAYER }), query: { id: privateId } }),
    );
    const body = res.body as SuccessionFetchResponse;
    expect(body.snapshots[0]!.id).toBe(privateId);
  });

  it("rejects a missing token (401)", async () => {
    await expect(handler()(makeRequest({ method: "GET" }))).rejects.toMatchObject({
      code: "unauthorized",
    });
  });
});
