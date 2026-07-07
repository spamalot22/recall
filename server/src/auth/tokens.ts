import { createHash, createHmac, randomBytes } from "node:crypto";

export function createRefreshToken() {
  return randomBytes(32).toString("base64url");
}

export function hashRefreshToken(token: string, secret: string) {
  return createHmac("sha256", secret).update(token).digest("base64url");
}

export function shortTokenFingerprint(token: string) {
  return createHash("sha256").update(token).digest("hex").slice(0, 12);
}
