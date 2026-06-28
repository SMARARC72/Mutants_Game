// OpenAI provider behind a narrow interface (ADR-007, TDD §7.3 steps 4–5). The gen proxy is
// the ONLY holder of the OpenAI key. Mocking this interface lets the whole pipeline — and the
// generate-once invariant — run offline in CI with zero network and zero real keys.

import { ApiError } from "./errors.js";

export interface ModerationResult {
  readonly flagged: boolean;
  /** Category → flagged, for logging the reason (TDD §9.3). */
  readonly categories: Readonly<Record<string, boolean>>;
}

export interface GeneratedImage {
  /** Raw image bytes to stream to Storage. */
  readonly bytes: Uint8Array;
  readonly contentType: string;
  readonly model: string;
}

export interface ImageGenProvider {
  /** Step 4: moderate the prompt before spending on generation. */
  moderate(input: string): Promise<ModerationResult>;
  /** Step 5: generate the image from the deterministic prompt + sigil seed. */
  generateImage(args: { prompt: string; seed: number }): Promise<GeneratedImage>;
}

interface OpenAiProviderOptions {
  readonly apiKey: string;
  readonly model?: string;
  readonly moderationModel?: string;
  /** Injectable for tests; defaults to global fetch. */
  readonly fetchImpl?: typeof fetch;
  readonly baseUrl?: string;
}

/**
 * Real OpenAI provider (used in production). Kept thin; all decisioning (reserve, cap,
 * persist) lives in the handler so this stays a dumb, replaceable client.
 */
export function openAiProvider(opts: OpenAiProviderOptions): ImageGenProvider {
  const fetchImpl = opts.fetchImpl ?? fetch;
  const base = opts.baseUrl ?? "https://api.openai.com/v1";
  const model = opts.model ?? "gpt-image-1";
  const moderationModel = opts.moderationModel ?? "omni-moderation-latest";
  const authHeaders = {
    Authorization: `Bearer ${opts.apiKey}`,
    "Content-Type": "application/json",
  };

  return {
    async moderate(input) {
      const res = await fetchImpl(`${base}/moderations`, {
        method: "POST",
        headers: authHeaders,
        body: JSON.stringify({ model: moderationModel, input }),
      });
      if (!res.ok) throw new ApiError("upstream_error", "Moderation request failed.");
      const data = (await res.json()) as {
        results?: Array<{ flagged: boolean; categories: Record<string, boolean> }>;
      };
      const first = data.results?.[0];
      return {
        flagged: first?.flagged ?? false,
        categories: first?.categories ?? {},
      };
    },

    async generateImage({ prompt, seed }) {
      // gpt-image-1 returns b64 by default. Forward `seed` for deterministic generation.
      const res = await fetchImpl(`${base}/images/generations`, {
        method: "POST",
        headers: authHeaders,
        body: JSON.stringify({ model, prompt, seed, n: 1, size: "1024x1024" }),
      });
      if (!res.ok) throw new ApiError("upstream_error", "Image generation failed.");
      const data = (await res.json()) as { data?: Array<{ b64_json?: string }> };
      const b64 = data.data?.[0]?.b64_json;
      if (!b64) throw new ApiError("upstream_error", "Image generation returned no data.");
      return {
        bytes: Uint8Array.from(Buffer.from(b64, "base64")),
        contentType: "image/png",
        model,
      };
    },
  };
}
