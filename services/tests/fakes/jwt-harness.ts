// Real-crypto JWT harness for tests. Generates an EC P-256 keypair, exposes its public JWK
// via a fake JwksSource, and mints ES256-signed tokens. This exercises the PRODUCTION
// `jwksVerifier` (real signature verification) — not a stub — so the authz tests prove the
// actual verification path, including rejection of tampered/foreign-signed tokens.

import { generateKeyPairSync, sign as cryptoSign, type KeyObject } from "node:crypto";
import type { JwksKey, JwksSource } from "../../lib/jwt.js";

function b64url(buf: Buffer): string {
  return buf.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export interface SignOptions {
  readonly sub?: string;
  readonly exp?: number; // seconds since epoch
  readonly iss?: string;
  readonly role?: string;
  readonly is_anonymous?: boolean;
  readonly kid?: string;
}

export interface JwtHarness {
  readonly source: JwksSource;
  readonly kid: string;
  /** Mint a valid ES256 token signed by this harness's key. */
  sign(opts?: SignOptions): string;
  /** The raw public key (for cross-key negative tests). */
  readonly publicKey: KeyObject;
}

export function makeJwtHarness(kid = "test-key-1"): JwtHarness {
  const { publicKey, privateKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const jwk = publicKey.export({ format: "jwk" }) as Record<string, unknown>;
  const jwksKey: JwksKey = {
    kty: String(jwk["kty"]),
    crv: jwk["crv"] as string,
    x: jwk["x"] as string,
    y: jwk["y"] as string,
    alg: "ES256",
    use: "sig",
    kid,
  };

  const source: JwksSource = {
    async getKeys() {
      return [jwksKey];
    },
  };

  return {
    source,
    kid,
    publicKey,
    sign(opts: SignOptions = {}): string {
      const headerSeg = b64url(
        Buffer.from(JSON.stringify({ alg: "ES256", typ: "JWT", kid: opts.kid ?? kid })),
      );
      const now = Math.floor(Date.now() / 1000);
      const payload = {
        sub: opts.sub ?? "11111111-1111-4111-8111-111111111111",
        role: opts.role ?? "authenticated",
        aud: "authenticated",
        iat: now,
        exp: opts.exp ?? now + 3600,
        ...(opts.iss !== undefined ? { iss: opts.iss } : {}),
        ...(opts.is_anonymous !== undefined ? { is_anonymous: opts.is_anonymous } : {}),
      };
      const payloadSeg = b64url(Buffer.from(JSON.stringify(payload)));
      const signingInput = `${headerSeg}.${payloadSeg}`;
      const signature = cryptoSign("sha256", Buffer.from(signingInput), {
        key: privateKey,
        dsaEncoding: "ieee-p1363",
      });
      return `${signingInput}.${b64url(signature)}`;
    },
  };
}
