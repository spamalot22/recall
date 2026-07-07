import argon2 from "argon2";

const memoryCost = 19456;
const parallelism = 1;
const timeCost = 2;

export async function hashPassword(password: string) {
  return argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost,
    parallelism,
    timeCost
  });
}

export async function verifyPassword(hash: string, password: string) {
  return argon2.verify(hash, password);
}
