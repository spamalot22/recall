import { and, desc, eq, gt, sql } from "drizzle-orm";
import type { FastifyInstance } from "fastify";
import { randomUUID } from "node:crypto";
import { z } from "zod";

import { auditEvents, encryptedRecords, syncCursors } from "../db/schema.js";

const encryptedRecordSchema = z.object({
  id: z.string().uuid(),
  type: z.enum(["note", "checklist_item", "reminder", "reminder_occurrence", "tombstone"]),
  encryptedPayload: z.string().min(1).max(700_000),
  payloadVersion: z.number().int().positive().default(1),
  clientRevision: z.number().int().nonnegative(),
  baseServerRevision: z.number().int().nonnegative().optional(),
  deletedAt: z.string().datetime().optional().nullable()
});

const pushSchema = z.object({
  records: z.array(encryptedRecordSchema).min(1).max(250)
});

const pullSchema = z.object({
  afterServerRevision: z.number().int().nonnegative().default(0),
  limit: z.number().int().min(1).max(500).default(250)
});

export async function syncRoutes(app: FastifyInstance) {
  app.post("/sync/push", { preHandler: [app.authenticate] }, async (request) => {
    const input = pushSchema.parse(request.body);
    const userId = request.user.userId;
    const accepted = await app.db.transaction(async (tx) => {
      const acceptedRecords = [];

      await tx.execute(sql`select pg_advisory_xact_lock(hashtext(${userId}))`);

      const [latest] = await tx
        .select({ serverRevision: encryptedRecords.serverRevision })
        .from(encryptedRecords)
        .where(eq(encryptedRecords.userId, userId))
        .orderBy(desc(encryptedRecords.serverRevision))
        .limit(1);

      let nextServerRevision = (latest?.serverRevision ?? 0) + 1;

      for (const record of input.records) {
        const [existing] = await tx
          .select()
          .from(encryptedRecords)
          .where(and(eq(encryptedRecords.id, record.id), eq(encryptedRecords.userId, userId)))
          .limit(1);

        const deletedAt = record.deletedAt ? new Date(record.deletedAt) : null;

        if (!existing) {
          const serverRevision = nextServerRevision++;
          const [inserted] = await tx
            .insert(encryptedRecords)
            .values({
              id: record.id,
              userId,
              type: record.type,
              encryptedPayload: record.encryptedPayload,
              payloadVersion: record.payloadVersion,
              clientRevision: record.clientRevision,
              serverRevision,
              sourceDeviceId: request.user.deviceId,
              deletedAt
            })
            .returning();

          acceptedRecords.push({
            clientRecordId: record.id,
            serverRecordId: inserted.id,
            serverRevision: inserted.serverRevision,
            conflict: false
          });
          continue;
        }

        if (record.baseServerRevision === existing.serverRevision) {
          const serverRevision = nextServerRevision++;
          const [updated] = await tx
            .update(encryptedRecords)
            .set({
              type: record.type,
              encryptedPayload: record.encryptedPayload,
              payloadVersion: record.payloadVersion,
              clientRevision: record.clientRevision,
              serverRevision,
              sourceDeviceId: request.user.deviceId,
              deletedAt,
              updatedAt: new Date()
            })
            .where(and(eq(encryptedRecords.id, record.id), eq(encryptedRecords.userId, userId)))
            .returning();

          acceptedRecords.push({
            clientRecordId: record.id,
            serverRecordId: updated.id,
            serverRevision: updated.serverRevision,
            conflict: false
          });
          continue;
        }

        const conflictRecordId = randomUUID();
        const conflictServerRevision = nextServerRevision++;
        const [conflict] = await tx
          .insert(encryptedRecords)
          .values({
            id: conflictRecordId,
            userId,
            type: existing.type,
            encryptedPayload: existing.encryptedPayload,
            payloadVersion: existing.payloadVersion,
            clientRevision: existing.clientRevision,
            serverRevision: conflictServerRevision,
            sourceDeviceId: existing.sourceDeviceId,
            conflictOfRecordId: existing.id,
            deletedAt: existing.deletedAt
          })
          .returning();

        const serverRevision = nextServerRevision++;
        const [updated] = await tx
          .update(encryptedRecords)
          .set({
            type: record.type,
            encryptedPayload: record.encryptedPayload,
            payloadVersion: record.payloadVersion,
            clientRevision: record.clientRevision,
            serverRevision,
            sourceDeviceId: request.user.deviceId,
            deletedAt,
            updatedAt: new Date()
          })
          .where(and(eq(encryptedRecords.id, record.id), eq(encryptedRecords.userId, userId)))
          .returning();

        acceptedRecords.push({
          clientRecordId: record.id,
          serverRecordId: updated.id,
          serverRevision: updated.serverRevision,
          conflict: true,
          conflictOfRecordId: existing.id,
          conflictRecordId: conflict.id
        });
      }

      return acceptedRecords;
    });

    await app.db.insert(auditEvents).values({
      action: "sync_push",
      userId,
      deviceId: request.user.deviceId,
      ipAddress: request.ip,
      userAgent: request.headers["user-agent"],
      metadata: { count: input.records.length }
    });

    return { accepted };
  });

  app.post("/sync/pull", { preHandler: [app.authenticate] }, async (request) => {
    const input = pullSchema.parse(request.body);
    const userId = request.user.userId;

    const records = await app.db
      .select({
        id: encryptedRecords.id,
        type: encryptedRecords.type,
        encryptedPayload: encryptedRecords.encryptedPayload,
        payloadVersion: encryptedRecords.payloadVersion,
        clientRevision: encryptedRecords.clientRevision,
        serverRevision: encryptedRecords.serverRevision,
        conflictOfRecordId: encryptedRecords.conflictOfRecordId,
        deletedAt: encryptedRecords.deletedAt
      })
      .from(encryptedRecords)
      .where(and(eq(encryptedRecords.userId, userId), gt(encryptedRecords.serverRevision, input.afterServerRevision)))
      .orderBy(encryptedRecords.serverRevision)
      .limit(input.limit);

    const lastServerRevision = records.at(-1)?.serverRevision ?? input.afterServerRevision;

    const [existingCursor] = await app.db
      .select({ id: syncCursors.id })
      .from(syncCursors)
      .where(eq(syncCursors.deviceId, request.user.deviceId))
      .limit(1);

    if (existingCursor) {
      await app.db
        .update(syncCursors)
        .set({ lastServerRevision, updatedAt: new Date() })
        .where(eq(syncCursors.id, existingCursor.id));
    } else {
      await app.db.insert(syncCursors).values({
        userId,
        deviceId: request.user.deviceId,
        lastServerRevision
      });
    }

    await app.db.insert(auditEvents).values({
      action: "sync_pull",
      userId,
      deviceId: request.user.deviceId,
      ipAddress: request.ip,
      userAgent: request.headers["user-agent"],
      metadata: { count: records.length, afterServerRevision: input.afterServerRevision }
    });

    return {
      records,
      cursor: {
        lastServerRevision,
        hasMore: records.length === input.limit
      }
    };
  });
}
