import { z } from "zod";

const envBoolean = z.preprocess((value) => {
  if (typeof value !== "string") {
    return value;
  }
  if (value.toLowerCase() === "true") {
    return true;
  }
  if (value.toLowerCase() === "false") {
    return false;
  }
  return value;
}, z.boolean());

const optionalEnvString = (schema: z.ZodString) =>
  z.preprocess((value) => (value === "" ? undefined : value), schema.optional());

const configSchema = z.object({
  DATABASE_URL: z.string().url(),
  DRIZZLE_MIGRATIONS_DIR: z.string().default("./drizzle"),
  HOST: z.string().default("0.0.0.0"),
  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  LOG_LEVEL: z.string().default("info"),
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().min(1).max(65535).default(8787),
  PUBLIC_REGISTRATION_ENABLED: envBoolean.default(false),
  RECALL_BOOTSTRAP_EMAIL: optionalEnvString(z.string().email()),
  RECALL_BOOTSTRAP_PASSWORD: optionalEnvString(z.string().min(16)),
  RUN_MIGRATIONS: envBoolean.default(true),
  TRUST_PROXY: z.string().trim().default("")
}).superRefine((config, context) => {
  if (config.NODE_ENV !== "production") {
    return;
  }

  const placeholderFragments = ["change-this", "replace-me", "example-secret"];
  for (const [field, value] of [
    ["JWT_ACCESS_SECRET", config.JWT_ACCESS_SECRET],
    ["JWT_REFRESH_SECRET", config.JWT_REFRESH_SECRET]
  ] as const) {
    if (placeholderFragments.some((fragment) => value.toLowerCase().includes(fragment))) {
      context.addIssue({
        code: "custom",
        path: [field],
        message: "Production secrets must not use example placeholder values."
      });
    }
    if (value.length < 48 || new Set(value).size < 12) {
      context.addIssue({
        code: "custom",
        path: [field],
        message: "Production JWT secrets must be at least 48 characters with sufficient diversity."
      });
    }
  }

  if (config.JWT_ACCESS_SECRET === config.JWT_REFRESH_SECRET) {
    context.addIssue({
      code: "custom",
      path: ["JWT_REFRESH_SECRET"],
      message: "Access and refresh token secrets must be different."
    });
  }

  const databaseUrl = new URL(config.DATABASE_URL);
  const databasePassword = decodeURIComponent(databaseUrl.password);
  if (
    !["postgres:", "postgresql:"].includes(databaseUrl.protocol) ||
    databasePassword.length < 16 ||
    placeholderFragments.some((fragment) => databasePassword.toLowerCase().includes(fragment))
  ) {
    context.addIssue({
      code: "custom",
      path: ["DATABASE_URL"],
      message: "Production PostgreSQL credentials must include a strong, non-placeholder password."
    });
  }

  if (
    config.RECALL_BOOTSTRAP_PASSWORD &&
    placeholderFragments.some((fragment) =>
      config.RECALL_BOOTSTRAP_PASSWORD!.toLowerCase().includes(fragment)
    )
  ) {
    context.addIssue({
      code: "custom",
      path: ["RECALL_BOOTSTRAP_PASSWORD"],
      message: "Production bootstrap credentials must not use example placeholder values."
    });
  }

  const proxyTrust = config.TRUST_PROXY.toLowerCase();
  if (["true", "false", "0.0.0.0/0", "::/0"].includes(proxyTrust)) {
    context.addIssue({
      code: "custom",
      path: ["TRUST_PROXY"],
      message: "Trust only explicit reverse-proxy IP addresses or narrow CIDR ranges."
    });
  }
});

export type AppConfig = z.infer<typeof configSchema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  return configSchema.parse(env);
}
