// Supabase JWT verification middleware (TDD §7.2). Every endpoint requires a valid Supabase
// access token in `Authorization: Bearer <jwt>`; we verify it against the project JWKS and
// extract `sub` = player id. Asymmetric keys (ES256/RS256) are fetched from the project's
// `/.well-known/jwks.json` and cached. The verifier is exposed behind the `JwtVerifier`
// interface so tests inject a deterministic fake (no network, no real keys).

import { createPublicKey, verify as cryptoVerify, type KeyObject } from "node:crypto";
import { ApiError } from "./errors.js";
import { header, type ServiceRequest } from "./http.js";

/** The authenticated principal extracted from a verified token. */
export interface AuthContext {
  /** Supabase Auth user id (`sub`) — this IS the player id (migration 0002). */
  readonly playerId: string;
  /** Raw verified claims, for endpoints that need role/aud/exp. */
  readonly claims: JwtClaims;
}

export interface JwtClaims {
  readonly sub: string;
  readonly role?: string;
  readonly aud?: string | string[];
  readonly exp?: number;
  readonly iat?: number;
  readonly iss?: string;
  readonly is_anonymous?: boolean;
  readonly [key: string]: unknown;
}

export interface JwtVerifier {
  /** Verify a compact JWS and return its claims, or throw `ApiError('unauthorized')`. */
  verify(token: string): Promise<JwtClaims>;
}

export interface JwksKey {
  kty: string;
  kid?: string;
  alg?: string;
  use?: string;
  crv?: string;
  n?: string;
  e?: string;
  x?: string;
  y?: string;
}

interface Jwks {
  keys: JwksKey[];
}

const SUPPORTED_ALGS = new Set(["RS256", "ES256"]);

function b64urlToBuffer(input: string): Buffer {
  const pad = (4 - (input.length % 4)) % 4;
  const b64 = input.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat(pad);
  return Buffer.from(b64, "base64");
}

function decodeJson<T>(segment: string): T {
  try {
    return JSON.parse(b64urlToBuffer(segment).toString("utf8")) as T;
  } catch {
    throw new ApiError("unauthorized", "Malformed token.");
  }
}

interface ParsedJws {
  header: { alg?: string; kid?: string; typ?: string };
  claims: JwtClaims;
  signingInput: string;
  signature: Buffer;
}

function parseJws(token: string): ParsedJws {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new ApiError("unauthorized", "Malformed token.");
  }
  const [h, p, s] = parts as [string, string, string];
  return {
    header: decodeJson(h),
    claims: decodeJson<JwtClaims>(p),
    signingInput: `${h}.${p}`,
    signature: b64urlToBuffer(s),
  };
}

function jwkToKeyObject(jwk: JwksKey): KeyObject {
  // Node accepts a JWK directly for public-key import.
  return createPublicKey({ key: jwk as unknown as Record<string, unknown>, format: "jwk" });
}

function verifySignature(alg: string, signingInput: string, signature: Buffer, key: KeyObject): boolean {
  const data = Buffer.from(signingInput, "utf8");
  if (alg === "RS256") {
    return cryptoVerify("RSA-SHA256", data, key, signature);
  }
  if (alg === "ES256") {
    // JWS ES256 signatures are raw r||s (64 bytes); Node expects DER unless we ask for ieee-p1363.
    return cryptoVerify(
      "sha256",
      data,
      { key, dsaEncoding: "ieee-p1363" },
      signature,
    );
  }
  return false;
}

/** Loads + caches a JWKS document. Injected so tests can stub key retrieval. */
export interface JwksSource {
  getKeys(): Promise<JwksKey[]>;
}

/** Default JWKS source: fetches `<SUPABASE_URL>/auth/v1/.well-known/jwks.json`, cached. */
export function httpJwksSource(supabaseUrl: string, ttlMs = 10 * 60 * 1000): JwksSource {
  const url = `${supabaseUrl.replace(/\/$/, "")}/auth/v1/.well-known/jwks.json`;
  let cache: { keys: JwksKey[]; at: number } | null = null;
  return {
    async getKeys() {
      const now = Date.now();
      if (cache && now - cache.at < ttlMs) return cache.keys;
      const res = await fetch(url);
      if (!res.ok) {
        throw new ApiError("upstream_error", "Could not fetch signing keys.");
      }
      const doc = (await res.json()) as Jwks;
      cache = { keys: doc.keys ?? [], at: now };
      return cache.keys;
    },
  };
}

export interface JwksVerifierOptions {
  /** Reject tokens not issued by this issuer (defaults to `<SUPABASE_URL>/auth/v1`). */
  readonly issuer?: string;
  /** Clock skew tolerance in seconds (default 5s). */
  readonly clockToleranceSec?: number;
  /** Override the current time (tests). */
  readonly now?: () => number;
}

/**
 * Production verifier: asymmetric signature check against the JWKS + exp/iss validation.
 */
export function jwksVerifier(source: JwksSource, opts: JwksVerifierOptions = {}): JwtVerifier {
  const tolerance = opts.clockToleranceSec ?? 5;
  const now = opts.now ?? (() => Math.floor(Date.now() / 1000));
  return {
    async verify(token: string): Promise<JwtClaims> {
      const { header: h, claims, signingInput, signature } = parseJws(token);
      const alg = h.alg ?? "";
      if (!SUPPORTED_ALGS.has(alg)) {
        throw new ApiError("unauthorized", "Unsupported token algorithm.");
      }

      const keys = await source.getKeys();
      const candidates = h.kid ? keys.filter((k) => k.kid === h.kid) : keys;
      if (candidates.length === 0) {
        throw new ApiError("unauthorized", "No matching signing key.");
      }

      const verified = candidates.some((jwk) => {
        try {
          return verifySignature(alg, signingInput, signature, jwkToKeyObject(jwk));
        } catch {
          return false;
        }
      });
      if (!verified) {
        throw new ApiError("unauthorized", "Invalid token signature.");
      }

      const t = now();
      if (typeof claims.exp === "number" && claims.exp + tolerance < t) {
        throw new ApiError("unauthorized", "Token expired.");
      }
      if (opts.issuer && claims.iss && claims.iss !== opts.issuer) {
        throw new ApiError("unauthorized", "Unexpected token issuer.");
      }
      if (typeof claims.sub !== "string" || claims.sub.length === 0) {
        throw new ApiError("unauthorized", "Token missing subject.");
      }
      return claims;
    },
  };
}

/**
 * Extract + verify the bearer token from a request, returning the auth context.
 * Throws `ApiError('unauthorized')` when the header is missing/malformed or the token fails
 * verification.
 */
export async function authenticate(req: ServiceRequest, verifier: JwtVerifier): Promise<AuthContext> {
  const raw = header(req, "authorization");
  if (!raw) {
    throw new ApiError("unauthorized", "Missing Authorization header.");
  }
  const match = /^Bearer\s+(.+)$/i.exec(raw.trim());
  if (!match || !match[1]) {
    throw new ApiError("unauthorized", "Authorization header must be 'Bearer <token>'.");
  }
  const claims = await verifier.verify(match[1].trim());
  return { playerId: claims.sub, claims };
}
