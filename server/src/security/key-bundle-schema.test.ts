import { describe, expect, it } from "vitest";

import { keyBundleInputSchema } from "./key-bundle-schema.js";

const validBundle = {
  passwordWrappedMasterKey: JSON.stringify({
    algorithm: "aes-256-gcm",
    kdf: "pbkdf2-hmac-sha256",
    salt: "a".repeat(22) + "==",
    encryptedKey: "b".repeat(80)
  }),
  recoveryWrappedMasterKey: JSON.stringify({
    algorithm: "aes-256-gcm",
    kdf: "pbkdf2-hmac-sha256",
    salt: "c".repeat(22) + "==",
    encryptedKey: "d".repeat(80)
  }),
  recoveryVerifier: "e".repeat(43),
  kdfParams: {
    algorithm: "pbkdf2-hmac-sha256",
    iterations: 310_000,
    bits: 256
  },
  version: 1
};

describe("keyBundleInputSchema", () => {
  it("accepts the supported encrypted bundle format", () => {
    expect(keyBundleInputSchema.parse(validBundle)).toEqual(validBundle);
  });

  it("rejects weak KDF settings and unsupported wrapping algorithms", () => {
    expect(() =>
      keyBundleInputSchema.parse({
        ...validBundle,
        kdfParams: { ...validBundle.kdfParams, iterations: 1 }
      })
    ).toThrow();
    expect(() =>
      keyBundleInputSchema.parse({
        ...validBundle,
        passwordWrappedMasterKey: JSON.stringify({
          algorithm: "aes-256-cbc",
          kdf: "pbkdf2-hmac-sha256",
          salt: "a".repeat(22) + "==",
          encryptedKey: "b".repeat(80)
        })
      })
    ).toThrow();
  });
});
