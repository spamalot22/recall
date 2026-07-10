import { describe, expect, it } from "vitest";

import { loadConfig } from "./config.js";

describe("loadConfig", () => {
  it("loads secure defaults from environment variables", () => {
    const config = loadConfig({
      DATABASE_URL: "postgres://recall:recall@localhost:5432/recall",
      JWT_ACCESS_SECRET: "a".repeat(32),
      JWT_REFRESH_SECRET: "b".repeat(32),
      RECALL_BOOTSTRAP_EMAIL: "",
      RECALL_BOOTSTRAP_PASSWORD: ""
    });

    expect(config.PORT).toBe(8787);
    expect(config.PUBLIC_REGISTRATION_ENABLED).toBe(false);
    expect(config.RECALL_BOOTSTRAP_EMAIL).toBeUndefined();
    expect(config.RECALL_BOOTSTRAP_PASSWORD).toBeUndefined();
  });

  it("parses false boolean strings as false", () => {
    const config = loadConfig({
      DATABASE_URL: "postgres://recall:recall@localhost:5432/recall",
      JWT_ACCESS_SECRET: "a".repeat(32),
      JWT_REFRESH_SECRET: "b".repeat(32),
      PUBLIC_REGISTRATION_ENABLED: "false",
      RUN_MIGRATIONS: "false"
    });

    expect(config.PUBLIC_REGISTRATION_ENABLED).toBe(false);
    expect(config.RUN_MIGRATIONS).toBe(false);
  });

  it("rejects ambiguous boolean strings", () => {
    expect(() =>
      loadConfig({
        DATABASE_URL: "postgres://recall:recall@localhost:5432/recall",
        JWT_ACCESS_SECRET: "a".repeat(32),
        JWT_REFRESH_SECRET: "b".repeat(32),
        PUBLIC_REGISTRATION_ENABLED: "yes"
      })
    ).toThrow();
  });

  it("rejects unsafe production secrets", () => {
    expect(() =>
      loadConfig({
        DATABASE_URL: "postgres://recall:change-this-password@recall_db:5432/recall",
        JWT_ACCESS_SECRET: "same-secret".repeat(4),
        JWT_REFRESH_SECRET: "same-secret".repeat(4),
        NODE_ENV: "production"
      })
    ).toThrow();
  });

  it("accepts distinct production secrets and a strong database password", () => {
    const config = loadConfig({
      DATABASE_URL: "postgres://recall:a-long-random-database-password@recall_db:5432/recall",
      JWT_ACCESS_SECRET: "access-0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ-abcdefgh",
      JWT_REFRESH_SECRET: "refresh-zyxwvutsrqponmlkjihgfedcba-9876543210-ABCD",
      NODE_ENV: "production",
      TRUST_PROXY: "172.18.0.1/32"
    });

    expect(config.TRUST_PROXY).toBe("172.18.0.1/32");
  });

  it("rejects broad production proxy trust", () => {
    expect(() =>
      loadConfig({
        DATABASE_URL: "postgres://recall:a-long-random-database-password@recall_db:5432/recall",
        JWT_ACCESS_SECRET: "access-0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ-abcdefgh",
        JWT_REFRESH_SECRET: "refresh-zyxwvutsrqponmlkjihgfedcba-9876543210-ABCD",
        NODE_ENV: "production",
        TRUST_PROXY: "0.0.0.0/0"
      })
    ).toThrow();
  });
});
