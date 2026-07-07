import { drizzle } from "drizzle-orm/node-postgres";
import pg from "pg";

import type { AppConfig } from "../config.js";
import * as schema from "./schema.js";

const { Pool } = pg;

export function createDb(config: AppConfig) {
  const pool = new Pool({
    connectionString: config.DATABASE_URL,
    max: 10
  });

  return {
    db: drizzle(pool, { schema }),
    pool
  };
}
