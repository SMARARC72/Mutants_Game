import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/**/*.test.ts"],
    environment: "node",
    globals: false,
    clearMocks: true,
    coverage: {
      provider: "v8",
      include: ["lib/**/*.ts", "api/**/*.ts"],
      exclude: ["lib/types.ts"],
    },
  },
});
