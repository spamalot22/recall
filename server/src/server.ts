import Fastify from "fastify";

import type { AppConfig } from "./config.js";
import { createDb } from "./db/client.js";
import { runMigrations } from "./db/migrate.js";
import { bootstrapInitialUser } from "./auth/bootstrap.js";
import { registerAuthenticateDecorator } from "./plugins/authenticate.js";
import { registerSecurityPlugins } from "./plugins/security.js";
import { authRoutes } from "./routes/auth.js";
import { healthRoutes } from "./routes/health.js";
import { keyBundleRoutes } from "./routes/key-bundles.js";
import { syncRoutes } from "./routes/sync.js";
import { ZodError } from "zod";

export async function buildServer(config: AppConfig) {
  const app = Fastify({
    logger: {
      level: config.LOG_LEVEL
    },
    trustProxy: true,
    bodyLimit: 1024 * 1024
  });

  const { db, pool } = createDb(config);

  app.decorate("db", db);
  app.decorate("pgPool", pool);

  app.addHook("onClose", async () => {
    await pool.end();
  });

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof ZodError) {
      request.log.warn({ error }, "Request validation failed.");
      return reply.code(400).send({
        error: "validation_failed",
        issues: error.issues.map((issue) => ({
          path: issue.path,
          message: issue.message
        }))
      });
    }

    request.log.error(error);
    return reply.code(500).send({ error: "internal_server_error" });
  });

  await registerSecurityPlugins(app, config);
  await registerAuthenticateDecorator(app);
  await healthRoutes(app);
  await authRoutes(app, config);
  await keyBundleRoutes(app);
  await syncRoutes(app);

  app.addHook("onReady", async () => {
    await runMigrations({ db, pool }, config);
    await bootstrapInitialUser({ db, pool }, config, app.log);
  });

  return app;
}
