import { z } from "zod";

const wrappedMasterKeyObjectSchema = z.object({
  algorithm: z.literal("aes-256-gcm"),
  kdf: z.literal("pbkdf2-hmac-sha256"),
  salt: z.string().regex(/^[A-Za-z0-9_-]{22}={0,2}$/),
  encryptedKey: z.string().regex(/^[A-Za-z0-9_-]{80}={0,2}$/)
});

const wrappedMasterKeySchema = z.string().min(1).max(4096).superRefine((value, context) => {
  try {
    wrappedMasterKeyObjectSchema.parse(JSON.parse(value));
  } catch {
    context.addIssue({ code: "custom", message: "Invalid wrapped master key." });
  }
});

export const recoveryVerifierSchema = z.string().regex(/^[A-Za-z0-9_-]{43}$/);

export const keyBundleInputSchema = z.object({
  passwordWrappedMasterKey: wrappedMasterKeySchema,
  recoveryWrappedMasterKey: wrappedMasterKeySchema,
  recoveryVerifier: recoveryVerifierSchema,
  kdfParams: z.object({
    algorithm: z.literal("pbkdf2-hmac-sha256"),
    iterations: z.number().int().min(310_000).max(1_000_000),
    bits: z.literal(256)
  }),
  version: z.literal(1).default(1)
});
