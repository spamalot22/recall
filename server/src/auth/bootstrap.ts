import { count } from "drizzle-orm";

import type { AppConfig } from "../config.js";
import type { createDb } from "../db/client.js";
import { auditEvents, users } from "../db/schema.js";
import { hashPassword } from "./passwords.js";

type DbContext = ReturnType<typeof createDb>;

export async function bootstrapInitialUser(
  context: DbContext,
  config: AppConfig,
  logger: { info: (message: string) => void; warn: (message: string) => void }
) {
  const [result] = await context.db.select({ value: count() }).from(users);

  if (result.value > 0) {
    if (config.RECALL_BOOTSTRAP_EMAIL || config.RECALL_BOOTSTRAP_PASSWORD) {
      logger.warn("Bootstrap credentials are configured but ignored because users already exist.");
    }
    return;
  }

  if (!config.RECALL_BOOTSTRAP_EMAIL || !config.RECALL_BOOTSTRAP_PASSWORD) {
    logger.warn("No users exist and bootstrap credentials are not configured.");
    return;
  }

  const [user] = await context.db
    .insert(users)
    .values({
      email: config.RECALL_BOOTSTRAP_EMAIL.toLowerCase(),
      passwordHash: await hashPassword(config.RECALL_BOOTSTRAP_PASSWORD),
      isAdmin: true
    })
    .returning({ id: users.id });

  await context.db.insert(auditEvents).values({
    userId: user.id,
    action: "bootstrap_user_created",
    metadata: { source: "env" }
  });

  logger.info("Bootstrap admin user created.");
}
