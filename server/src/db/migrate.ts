import { migrate } from "drizzle-orm/node-postgres/migrator";

import type { AppConfig } from "../config.js";
import type { createDb } from "./client.js";

type DbContext = ReturnType<typeof createDb>;

export async function runMigrations(context: DbContext, config: AppConfig) {
  if (!config.RUN_MIGRATIONS) {
    return;
  }

  await migrate(context.db, {
    migrationsFolder: config.DRIZZLE_MIGRATIONS_DIR
  });
}
