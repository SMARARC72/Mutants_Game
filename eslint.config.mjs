// Flat ESLint config — Phase 0. Lints the Node tooling/tests (ESM). Game code is GDScript
// (gdlint) / Python (engines) / SQL (sqlfluff), handled by their own linters.
import js from "@eslint/js";
import globals from "globals";

export default [
  {
    ignores: ["**/node_modules/**", "client/addons/**", "**/.godot/**"],
  },
  js.configs.recommended,
  {
    files: ["**/*.mjs", "**/*.js"],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: "module",
      globals: { ...globals.node },
    },
    rules: {
      "no-unused-vars": ["warn", { argsIgnorePattern: "^_", varsIgnorePattern: "^_" }],
    },
  },
];
