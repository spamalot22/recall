import { describe, expect, it } from "vitest";

import {
  pullSchema,
  pushSchema,
  syncCapabilitiesSchema,
  syncProtocolVersion
} from "./sync.js";

describe("sync protocol compatibility", () => {
  it("rejects clients that predate anchored reminder support", () => {
    const record = {
      id: "0198a3b4-8e80-7000-8000-000000000001",
      type: "note",
      encryptedPayload: "encrypted",
      clientRevision: 1
    };

    expect(
      pullSchema.safeParse({ afterServerRevision: 0, limit: 250 }).success
    ).toBe(false);
    expect(pushSchema.safeParse({ records: [record] }).success).toBe(false);
    expect(
      pushSchema.safeParse({
        protocolVersion: syncProtocolVersion,
        records: [record]
      }).success
    ).toBe(true);
  });

  it("accepts the current protocol on pull requests", () => {
    expect(
      pullSchema.safeParse({
        protocolVersion: syncProtocolVersion,
        afterServerRevision: 0,
        limit: 250
      }).success
    ).toBe(true);
    expect(
      syncCapabilitiesSchema.safeParse({
        protocolVersion: syncProtocolVersion
      }).success
    ).toBe(true);
  });
});
