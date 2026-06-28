// Helper to build a ServiceRequest for handler tests.

import type { ServiceRequest } from "../../lib/http.js";

export function makeRequest(init: {
  method?: string;
  token?: string;
  body?: unknown;
  query?: Record<string, string | undefined>;
  headers?: Record<string, string>;
}): ServiceRequest {
  const headers: Record<string, string | undefined> = {};
  for (const [k, v] of Object.entries(init.headers ?? {})) headers[k.toLowerCase()] = v;
  if (init.token) headers["authorization"] = `Bearer ${init.token}`;
  return {
    method: init.method ?? "POST",
    headers,
    query: init.query ?? {},
    body: init.body,
  };
}
