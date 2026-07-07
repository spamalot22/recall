import { z } from "zod";

const configSchema = z.object({
  DATABASE_URL: z.string().url(),
  DRIZZLE_MIGRATIONS_DIR: z.string().default("./drizzle"),
  HOST: z.string().default("0.0.0.0"),
  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  LOG_LEVEL: z.string().default("info"),
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().min(1).max(65535).default(8787),
  PUBLIC_REGISTRATION_ENABLED: z.coerce.boolean().default(false),
  RECALL_BOOTSTRAP_EMAIL: z.string().email().optional(),
  RECALL_BOOTSTRAP_PASSWORD: z.string().min(16).optional(),
  RUN_MIGRATIONS: z.coerce.boolean().default(true)
});

export type AppConfig = z.infer<typeof configSchema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  return configSchema.parse(env);
}
