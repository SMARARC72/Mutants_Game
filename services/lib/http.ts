// Runtime-agnostic HTTP contracts. Handlers are pure async functions over `ServiceRequest`
// → `ServiceResponse` so they unit-test offline without a live server. A thin adapter
// (api/_adapter.ts) maps a Vercel/Node request onto this shape.

import { ApiError, envelopeFor, type ErrorEnvelope } from "./errors.js";

export type HttpMethod = "GET" | "POST" | "PUT" | "PATCH" | "DELETE" | "OPTIONS";

export interface ServiceRequest {
  readonly method: string;
  /** Lower-cased header map (e.g. `authorization`). */
  readonly headers: Readonly<Record<string, string | undefined>>;
  /** Parsed query string params. */
  readonly query: Readonly<Record<string, string | undefined>>;
  /** Already-parsed JSON body (or `undefined` for bodyless requests). */
  readonly body: unknown;
}

export interface ServiceResponse<T = unknown> {
  readonly status: number;
  readonly body: T | ErrorEnvelope;
  readonly headers?: Readonly<Record<string, string>>;
}

export function ok<T>(body: T, headers?: Record<string, string>): ServiceResponse<T> {
  return { status: 200, body, ...(headers ? { headers } : {}) };
}

export function json<T>(
  status: number,
  body: T,
  headers?: Record<string, string>,
): ServiceResponse<T> {
  return { status, body, ...(headers ? { headers } : {}) };
}

/** Read a header case-insensitively (callers may pass mixed case). */
export function header(req: ServiceRequest, name: string): string | undefined {
  return req.headers[name.toLowerCase()];
}

/** Enforce HTTP method; throws a typed `method_not_allowed` otherwise. */
export function requireMethod(req: ServiceRequest, method: HttpMethod): void {
  if (req.method.toUpperCase() !== method) {
    throw new ApiError("method_not_allowed", `Expected ${method}, got ${req.method}.`);
  }
}

/**
 * Wrap a handler so every thrown `ApiError` (or unexpected error) becomes the canonical
 * error envelope + status. This is the single place errors cross the boundary.
 */
export function withErrorEnvelope(
  handler: (req: ServiceRequest) => Promise<ServiceResponse>,
): (req: ServiceRequest) => Promise<ServiceResponse> {
  return async (req) => {
    try {
      return await handler(req);
    } catch (err) {
      const { status, body } = envelopeFor(err);
      return { status, body };
    }
  };
}
