import { and, desc, eq, gt, lte, sql } from "drizzle-orm";
import type { FastifyInstance } from "fastify";
import { randomUUID } from "node:crypto";
import { z } from "zod";

import { auditEvents, encryptedRecords, syncCursors } from "../db/schema.js";

const encryptedRecordSchema = z.object({
  id: z.string().uuid(),
  type: z.enum(["note", "checklist_item", "reminder", "reminder_occurrence", "tombstone"]),
  encryptedPayload: z.string().min(1).max(700_000).regex(/^[A-Za-z0-9_-]+={0,2}$/),
  payloadVersion: z.number().int().positive().default(1),
  clientRevision: z.number().int().nonnegative(),
  baseServerRevision: z.number().int().nonnegative().optional(),
  deletedAt: z.string().datetime().optional().nullable()
});

export const syncProtocolVersion = 2;
export const syncCapabilitiesSchema = z.object({
  protocolVersion: z.literal(syncProtocolVersion)
});

export const pushSchema = z.object({
  protocolVersion: z.literal(syncProtocolVersion),
  records: z.array(encryptedRecordSchema).min(1).max(250)
});

export const pullSchema = z.object({
  protocolVersion: z.literal(syncProtocolVersion),
  afterServerRevision: z.number().int().nonnegative().default(0),
  limit: z.number().int().min(1).max(500).default(250)
});

export async function syncRoutes(app: FastifyInstance) {
  app.post(
    "/sync/capabilities",
    { preHandler: [app.authenticate] },
    async (request) => {
      syncCapabilitiesSchema.parse(request.body);
      return { protocolVersion: syncProtocolVersion, payloadVersions: [1, 2] };
    }
  );

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

        if (existing.sourceDeviceId === request.user.deviceId &&
            existing.clientRevision === record.clientRevision &&
            existing.encryptedPayload === record.encryptedPayload &&
            existing.type === record.type && existing.payloadVersion === record.payloadVersion &&
            existing.deletedAt?.getTime() === deletedAt?.getTime()) {
          acceptedRecords.push({
            clientRecordId: record.id,
            serverRecordId: existing.id,
            serverRevision: existing.serverRevision,
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
              conflictOfRecordId: null,
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
            conflictOfRecordId: existing.conflictOfRecordId ?? existing.id,
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
            conflictOfRecordId: null,
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

    // Bound bytes as well as record count to match the app's 1 MiB limit.
    const page = app.db.$with("pull_page").as(app.db
      .select({
        id: encryptedRecords.id,
        type: encryptedRecords.type,
        encryptedPayload: encryptedRecords.encryptedPayload,
        payloadVersion: encryptedRecords.payloadVersion,
        clientRevision: encryptedRecords.clientRevision,
        serverRevision: encryptedRecords.serverRevision,
        conflictOfRecordId: encryptedRecords.conflictOfRecordId,
        deletedAt: encryptedRecords.deletedAt,
        pageBytes: sql<number>`sum(octet_length(${encryptedRecords.encryptedPayload}) + 1024)
          over (order by ${encryptedRecords.serverRevision})`.as("page_bytes")
      })
      .from(encryptedRecords)
      .where(and(eq(encryptedRecords.userId, userId), gt(encryptedRecords.serverRevision, input.afterServerRevision)))
      .orderBy(encryptedRecords.serverRevision)
      .limit(input.limit));
    const records = await app.db.with(page).select({
      id: page.id,
      type: page.type,
      encryptedPayload: page.encryptedPayload,
      payloadVersion: page.payloadVersion,
      clientRevision: page.clientRevision,
      serverRevision: page.serverRevision,
      conflictOfRecordId: page.conflictOfRecordId,
      deletedAt: page.deletedAt
    }).from(page).where(lte(page.pageBytes, 900_000)).orderBy(page.serverRevision);

    const lastServerRevision = records.at(-1)?.serverRevision ?? input.afterServerRevision;

    await app.db.insert(syncCursors).values({
        userId,
        deviceId: request.user.deviceId,
        lastServerRevision
      }).onConflictDoUpdate({
        target: syncCursors.deviceId,
        set: { lastServerRevision, updatedAt: new Date() }
      });

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
        hasMore: records.length > 0
      }
    };
  });
}
