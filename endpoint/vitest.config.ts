import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    projects: [
      {
        plugins: [cloudflareTest({ wrangler: { configPath: "./wrangler.jsonc" } })],
        test: { name: "worker", include: ["test/integration/**/*.test.ts"] },
      },
      { test: { name: "build", include: ["test/build/**/*.test.ts"], environment: "node" } },
    ],
  },
});
