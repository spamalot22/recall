import { eq } from "drizzle-orm";
import type { FastifyInstance } from "fastify";

import { auditEvents, keyBundles } from "../db/schema.js";
import { keyBundleInputSchema } from "../security/key-bundle-schema.js";

export async function keyBundleRoutes(app: FastifyInstance) {
  app.get("/key-bundle", { preHandler: [app.authenticate] }, async (request, reply) => {
    const [bundle] = await app.db
      .select({
        passwordWrappedMasterKey: keyBundles.passwordWrappedMasterKey,
        recoveryWrappedMasterKey: keyBundles.recoveryWrappedMasterKey,
        kdfParams: keyBundles.kdfParams,
        version: keyBundles.version,
        updatedAt: keyBundles.updatedAt
      })
      .from(keyBundles)
      .where(eq(keyBundles.userId, request.user.userId))
      .limit(1);

    if (!bundle) {
      return reply.code(404).send({ error: "key_bundle_not_found" });
    }

    return { keyBundle: bundle };
  });

  app.put("/key-bundle", { preHandler: [app.authenticate] }, async (request, reply) => {
    const input = keyBundleInputSchema.parse(request.body);
    const [existing] = await app.db
      .select({ id: keyBundles.id })
      .from(keyBundles)
      .where(eq(keyBundles.userId, request.user.userId))
      .limit(1);

    if (existing) {
      return reply.code(409).send({ error: "key_bundle_already_exists" });
    }

    const values = {
      userId: request.user.userId,
      passwordWrappedMasterKey: input.passwordWrappedMasterKey,
      recoveryWrappedMasterKey: input.recoveryWrappedMasterKey,
      recoveryVerifier: input.recoveryVerifier,
      kdfParams: input.kdfParams,
      version: input.version,
      updatedAt: new Date()
    };

    const [bundle] = await app.db
      .insert(keyBundles)
      .values(values)
      .onConflictDoNothing({ target: keyBundles.userId })
      .returning();

    if (!bundle) {
      return reply.code(409).send({ error: "key_bundle_already_exists" });
    }

    await app.db.insert(auditEvents).values({
      action: "key_bundle_updated",
      userId: request.user.userId,
      deviceId: request.user.deviceId,
      ipAddress: request.ip,
      userAgent: request.headers["user-agent"]
    });

    return reply.code(201).send({
      keyBundle: {
        version: bundle.version,
        updatedAt: bundle.updatedAt.toISOString()
      }
    });
  });
}
