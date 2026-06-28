// Error envelope (TDD §7.6): every failure response is `{ error: { code, message, details? } }`.
// One typed taxonomy so handlers + tests agree on shape and HTTP status.

export type ErrorCode =
  | "unauthorized" // missing / invalid / expired JWT (401)
  | "forbidden" // valid JWT but not allowed to touch the resource (403)
  | "invalid_request" // zod validation failed (400)
  | "not_found" // resource does not exist (404)
  | "rate_limited" // per-player rate limit or monthly cap exceeded (429)
  | "moderation_blocked" // OpenAI moderation flagged the prompt/output (422)
  | "method_not_allowed" // wrong HTTP verb (405)
  | "upstream_error" // OpenAI / Storage / DB failure (502)
  | "internal_error"; // anything unexpected (500)

export interface ErrorDetails {
  readonly [key: string]: unknown;
}

export interface ErrorEnvelope {
  readonly error: {
    readonly code: ErrorCode;
    readonly message: string;
    readonly details?: ErrorDetails;
  };
}

export const ERROR_STATUS: Record<ErrorCode, number> = {
  unauthorized: 401,
  forbidden: 403,
  invalid_request: 400,
  not_found: 404,
  rate_limited: 429,
  moderation_blocked: 422,
  method_not_allowed: 405,
  upstream_error: 502,
  internal_error: 500,
};

/**
 * Typed application error. Carries the canonical `code` so the handler maps it to a
 * status + the `{error:{...}}` envelope without leaking internals (stack traces, key
 * material, raw upstream payloads).
 */
export class ApiError extends Error {
  readonly code: ErrorCode;
  readonly status: number;
  readonly details: ErrorDetails | undefined;

  constructor(code: ErrorCode, message: string, details?: ErrorDetails) {
    super(message);
    this.name = "ApiError";
    this.code = code;
    this.status = ERROR_STATUS[code];
    this.details = details;
  }

  toEnvelope(): ErrorEnvelope {
    return {
      error: {
        code: this.code,
        message: this.message,
        ...(this.details !== undefined ? { details: this.details } : {}),
      },
    };
  }
}

export function envelopeFor(err: unknown): { status: number; body: ErrorEnvelope } {
  if (err instanceof ApiError) {
    return { status: err.status, body: err.toEnvelope() };
  }
  // Never surface internals to the caller.
  return {
    status: ERROR_STATUS.internal_error,
    body: { error: { code: "internal_error", message: "Internal error." } },
  };
}
