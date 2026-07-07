import { describe, expect, it } from "vitest";

import { loadConfig } from "./config.js";

describe("loadConfig", () => {
  it("loads secure defaults from environment variables", () => {
    const config = loadConfig({
      DATABASE_URL: "postgres://recall:recall@localhost:5432/recall",
      JWT_ACCESS_SECRET: "a".repeat(32),
      JWT_REFRESH_SECRET: "b".repeat(32)
    });

    expect(config.PORT).toBe(8787);
    expect(config.PUBLIC_REGISTRATION_ENABLED).toBe(false);
  });
});
