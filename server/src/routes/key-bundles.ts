import { eq } from "drizzle-orm";
import type { FastifyInstance } from "fastify";
import { z } from "zod";

import { auditEvents, keyBundles } from "../db/schema.js";

const keyBundleSchema = z.object({
  passwordWrappedMasterKey: z.string().min(1),
  recoveryWrappedMasterKey: z.string().min(1),
  kdfParams: z.record(z.string(), z.unknown()),
  version: z.number().int().positive().default(1)
});

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

  app.put("/key-bundle", { preHandler: [app.authenticate] }, async (request) => {
    const input = keyBundleSchema.parse(request.body);
    const [existing] = await app.db
      .select({ id: keyBundles.id })
      .from(keyBundles)
      .where(eq(keyBundles.userId, request.user.userId))
      .limit(1);

    const values = {
      userId: request.user.userId,
      passwordWrappedMasterKey: input.passwordWrappedMasterKey,
      recoveryWrappedMasterKey: input.recoveryWrappedMasterKey,
      kdfParams: input.kdfParams,
      version: input.version,
      updatedAt: new Date()
    };

    const [bundle] = existing
      ? await app.db.update(keyBundles).set(values).where(eq(keyBundles.id, existing.id)).returning()
      : await app.db.insert(keyBundles).values(values).returning();

    await app.db.insert(auditEvents).values({
      action: "key_bundle_updated",
      userId: request.user.userId,
      deviceId: request.user.deviceId,
      ipAddress: request.ip,
      userAgent: request.headers["user-agent"]
    });

    return {
      keyBundle: {
        version: bundle.version,
        updatedAt: bundle.updatedAt.toISOString()
      }
    };
  });
}
