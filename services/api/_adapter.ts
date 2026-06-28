// Vercel Node-runtime adapter. Maps an incoming `VercelRequest` onto the runtime-agnostic
// `ServiceRequest`, runs the (already error-enveloped) handler, and writes the typed JSON
// response. Keeps the handlers free of Vercel types so they unit-test offline.

import type { IncomingMessage, ServerResponse } from "node:http";
import {
  requireMethod,
  withErrorEnvelope,
  type HttpMethod,
  type ServiceRequest,
  type ServiceResponse,
} from "../lib/http.js";

// Minimal Vercel request/response shape (avoids a @vercel/node dependency for the scaffold).
export interface VercelRequest extends IncomingMessage {
  query?: Record<string, string | string[] | undefined>;
  body?: unknown;
}
export type VercelResponse = ServerResponse;

function lowerHeaders(req: VercelRequest): Record<string, string | undefined> {
  const out: Record<string, string | undefined> = {};
  for (const [k, v] of Object.entries(req.headers)) {
    out[k.toLowerCase()] = Array.isArray(v) ? v[v.length - 1] : v;
  }
  return out;
}

function flattenQuery(req: VercelRequest): Record<string, string | undefined> {
  const out: Record<string, string | undefined> = {};
  for (const [k, v] of Object.entries(req.query ?? {})) {
    out[k] = Array.isArray(v) ? v[v.length - 1] : v;
  }
  return out;
}

async function readJsonBody(req: VercelRequest): Promise<unknown> {
  if (req.body !== undefined) return req.body; // Vercel pre-parses JSON bodies.
  const chunks: Buffer[] = [];
  for await (const chunk of req) chunks.push(chunk as Buffer);
  if (chunks.length === 0) return undefined;
  const raw = Buffer.concat(chunks).toString("utf8");
  if (raw.trim() === "") return undefined;
  try {
    return JSON.parse(raw);
  } catch {
    return undefined; // zod validation will reject; never throw on body parse.
  }
}

export async function toServiceRequest(req: VercelRequest): Promise<ServiceRequest> {
  return {
    method: req.method ?? "GET",
    headers: lowerHeaders(req),
    query: flattenQuery(req),
    body: await readJsonBody(req),
  };
}

export function sendServiceResponse(res: VercelResponse, out: ServiceResponse): void {
  res.statusCode = out.status;
  res.setHeader("Content-Type", "application/json");
  for (const [k, v] of Object.entries(out.headers ?? {})) res.setHeader(k, v);
  res.end(JSON.stringify(out.body));
}

/**
 * Build a Vercel route handler from a method + a `ServiceRequest`→`ServiceResponse` handler.
 * Wraps in the error envelope and enforces the method.
 */
export function vercelRoute(
  method: HttpMethod,
  handler: (req: ServiceRequest) => Promise<ServiceResponse>,
): (req: VercelRequest, res: VercelResponse) => Promise<void> {
  const wrapped = withErrorEnvelope(async (sreq) => {
    requireMethod(sreq, method);
    return handler(sreq);
  });
  return async (req, res) => {
    const sreq = await toServiceRequest(req);
    const out = await wrapped(sreq);
    sendServiceResponse(res, out);
  };
}
