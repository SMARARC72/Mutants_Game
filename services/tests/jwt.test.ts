import { describe, it, expect } from "vitest";
import { jwksVerifier, authenticate } from "../lib/jwt.js";
import { makeJwtHarness } from "./fakes/jwt-harness.js";
import { makeRequest } from "./fakes/request.js";

describe("JWT verification (real ES256 against a JWKS)", () => {
  it("verifies a valid token and extracts sub as playerId", async () => {
    const harness = makeJwtHarness();
    const verifier = jwksVerifier(harness.source);
    const ctx = await authenticate(
      makeRequest({ token: harness.sign({ sub: "player-123" }) }),
      verifier,
    );
    expect(ctx.playerId).toBe("player-123");
    expect(ctx.claims.role).toBe("authenticated");
  });

  it("carries is_anonymous claim (ADR-011 anonymous players)", async () => {
    const harness = makeJwtHarness();
    const verifier = jwksVerifier(harness.source);
    const ctx = await authenticate(
      makeRequest({ token: harness.sign({ sub: "anon-1", is_anonymous: true }) }),
      verifier,
    );
    expect(ctx.claims.is_anonymous).toBe(true);
  });

  it("rejects a token signed by a different key (tampered/foreign signature)", async () => {
    const real = makeJwtHarness();
    const attacker = makeJwtHarness("evil");
    const verifier = jwksVerifier(real.source); // only knows the real key
    await expect(verifier.verify(attacker.sign({ sub: "x" }))).rejects.toMatchObject({
      code: "unauthorized",
    });
  });

  it("rejects a structurally malformed token", async () => {
    const verifier = jwksVerifier(makeJwtHarness().source);
    await expect(verifier.verify("not.a.jwt.at.all")).rejects.toMatchObject({
      code: "unauthorized",
    });
    await expect(verifier.verify("garbage")).rejects.toMatchObject({ code: "unauthorized" });
  });

  it("rejects an expired token", async () => {
    const harness = makeJwtHarness();
    const verifier = jwksVerifier(harness.source);
    const expired = harness.sign({ exp: Math.floor(Date.now() / 1000) - 100 });
    await expect(verifier.verify(expired)).rejects.toMatchObject({ code: "unauthorized" });
  });

  it("rejects a token with an unexpected issuer when issuer is enforced", async () => {
    const harness = makeJwtHarness();
    const verifier = jwksVerifier(harness.source, { issuer: "https://expected.example/auth/v1" });
    const wrongIss = harness.sign({ iss: "https://evil.example/auth/v1" });
    await expect(verifier.verify(wrongIss)).rejects.toMatchObject({ code: "unauthorized" });
  });

  it("rejects 'alg: none' / unsupported algorithms", async () => {
    const harness = makeJwtHarness();
    const verifier = jwksVerifier(harness.source);
    // Hand-craft an unsigned 'none' token.
    const b64 = (o: unknown) =>
      Buffer.from(JSON.stringify(o)).toString("base64url");
    const none = `${b64({ alg: "none", typ: "JWT" })}.${b64({ sub: "x" })}.`;
    await expect(verifier.verify(none)).rejects.toMatchObject({ code: "unauthorized" });
  });

  it("rejects a missing/blank Authorization header", async () => {
    const verifier = jwksVerifier(makeJwtHarness().source);
    await expect(authenticate(makeRequest({}), verifier)).rejects.toMatchObject({
      code: "unauthorized",
    });
    await expect(
      authenticate(makeRequest({ headers: { authorization: "Token abc" } }), verifier),
    ).rejects.toMatchObject({ code: "unauthorized" });
  });
});
