import { describe, expect, it } from "vitest";

import { recoveryVerifierMatches } from "./auth.js";

describe("recoveryVerifierMatches", () => {
  it("matches equal recovery verifiers", () => {
    const verifier = "a".repeat(43);
    expect(recoveryVerifierMatches(verifier, verifier)).toBe(true);
  });

  it("rejects missing, different, and differently sized verifiers", () => {
    expect(recoveryVerifierMatches(null, "a".repeat(43))).toBe(false);
    expect(recoveryVerifierMatches("a".repeat(43), "b".repeat(43))).toBe(false);
    expect(recoveryVerifierMatches("a".repeat(43), "a".repeat(42))).toBe(false);
  });
});
