// Mock ImageGenProvider. Counts calls so tests can assert the generate-once invariant:
// the SECOND /api/art/generate for the same instance must make NO second generateImage call.

import type { GeneratedImage, ImageGenProvider, ModerationResult } from "../../lib/openai.js";

export interface FakeImageGen extends ImageGenProvider {
  moderateCalls: number;
  generateCalls: number;
  readonly lastPrompts: string[];
  /** Seeds received by generateImage(), in call order — lets tests assert seed forwarding. */
  readonly seeds: number[];
}

export interface FakeImageGenOptions {
  /** When true, moderate() returns flagged with these categories. */
  readonly flagged?: boolean;
  readonly flaggedCategories?: Record<string, boolean>;
  /** When true, generateImage() throws (simulate an OpenAI failure). */
  readonly failGeneration?: boolean;
}

export function makeFakeImageGen(opts: FakeImageGenOptions = {}): FakeImageGen {
  const fake: FakeImageGen = {
    moderateCalls: 0,
    generateCalls: 0,
    lastPrompts: [],
    seeds: [],

    async moderate(input: string): Promise<ModerationResult> {
      fake.moderateCalls += 1;
      fake.lastPrompts.push(input);
      if (opts.flagged) {
        return {
          flagged: true,
          categories: opts.flaggedCategories ?? { "sexual/minors": true },
        };
      }
      return { flagged: false, categories: {} };
    },

    async generateImage({ prompt, seed }): Promise<GeneratedImage> {
      fake.generateCalls += 1;
      fake.seeds.push(seed);
      if (opts.failGeneration) {
        throw new Error("simulated OpenAI failure");
      }
      return {
        bytes: Uint8Array.from(Buffer.from(`img:${prompt}`)),
        contentType: "image/png",
        model: "gpt-image-1-mock",
      };
    },
  };
  return fake;
}
