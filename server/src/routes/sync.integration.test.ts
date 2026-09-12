import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import Fastify, { type FastifyInstance } from "fastify";
import { randomUUID } from "node:crypto";
import { eq, inArray } from "drizzle-orm";
import { drizzle } from "drizzle-orm/node-postgres";
import { migrate } from "drizzle-orm/node-postgres/migrator";
import pg from "pg";

import * as schema from "../db/schema.js";
import { syncProtocolVersion, syncRoutes } from "./sync.js";

// CI supplies a disposable PostgreSQL service. Never fall back to DATABASE_URL.
const databaseUrl = process.env.RECALL_TEST_DATABASE_URL;
describe.skipIf(!databaseUrl)("PostgreSQL sync regressions", () => {
  let pool: pg.Pool;
  let app: FastifyInstance;
  let userId: string;
  let deviceId: string;
  const testUsers: string[] = [];

  beforeAll(async () => {
    pool = new pg.Pool({ connectionString: databaseUrl, max: 2 });
    const db = drizzle(pool, { schema });
    await migrate(db, { migrationsFolder: "./drizzle" });
    app = Fastify({ bodyLimit: 1024 * 1024 });
    app.decorate("db", db);
    app.decorate("authenticate", async (request) => {
      request.user = { userId, deviceId, sessionId: randomUUID() };
    });
    await app.register(syncRoutes);
    await app.ready();
  });

  beforeEach(async () => {
    userId = randomUUID();
    deviceId = randomUUID();
    testUsers.push(userId);
    await app.db.insert(schema.users).values({
      id: userId, email: `${userId}@example.invalid`, passwordHash: "test-only"
    });
    await app.db.insert(schema.devices).values({ id: deviceId, userId, name: "test" });
  });

  afterAll(async () => {
    try {
      if (app) {
        if (testUsers.length) {
          await app.db.delete(schema.users).where(inArray(schema.users.id, testUsers));
        }
        await app.close();
      }
    } finally {
      await pool?.end();
    }
  });

  async function push(record: Record<string, unknown>) {
    const response = await app.inject({
      method: "POST", url: "/sync/push",
      payload: { protocolVersion: syncProtocolVersion, records: [record] }
    });
    expect(response.statusCode, response.body).toBe(200);
    return response.json().accepted[0];
  }

  it("acknowledges a lost-response retry without making conflict copies", async () => {
    const record = { id: randomUUID(), type: "note", encryptedPayload: "YWJj", clientRevision: 1 };
    const first = await push(record);
    expect(await push(record)).toEqual(first);
    const records = await app.db.select().from(schema.encryptedRecords)
      .where(eq(schema.encryptedRecords.userId, userId));
    expect(records).toHaveLength(1);
  });

  it("preserves the encrypted identity of a conflict copied again", async () => {
    const id = randomUUID();
    await push({ id, type: "note", encryptedPayload: "YWJj", clientRevision: 1 });
    const conflict = await push({ id, type: "note", encryptedPayload: "ZGVm", clientRevision: 2 });
    expect(conflict.conflict).toBe(true);
    const next = await push({
      id: conflict.conflictRecordId, type: "note", encryptedPayload: "Z2hp", clientRevision: 3
    });
    const records = await app.db.select().from(schema.encryptedRecords)
      .where(eq(schema.encryptedRecords.userId, userId));
    expect(records.find((r) => r.id === next.conflictRecordId)?.conflictOfRecordId).toBe(id);
    expect(records.find((r) => r.id === conflict.conflictRecordId)?.conflictOfRecordId).toBeNull();
  });

  it("bounds pull bytes without skipping records and isolates each user", async () => {
    const ids = [randomUUID(), randomUUID(), randomUUID()];
    for (const id of ids) {
      await push({ id, type: "note", encryptedPayload: "a".repeat(500_000), clientRevision: 1 });
    }
    const ownerId = userId;
    let cursor = 0;
    const received: string[] = [];
    for (let page = 0; page < 4; page++) {
      const response = await app.inject({
        method: "POST", url: "/sync/pull",
        payload: { protocolVersion: syncProtocolVersion, afterServerRevision: cursor, limit: 250 }
      });
      expect(response.statusCode, response.body).toBe(200);
      expect(Buffer.byteLength(response.body)).toBeLessThan(1024 * 1024);
      const data = response.json();
      received.push(...data.records.map((r: { id: string }) => r.id));
      cursor = data.cursor.lastServerRevision;
      expect(data.cursor.hasMore).toBe(page < 3);
    }
    expect(received).toEqual(ids);
    userId = randomUUID();
    deviceId = randomUUID();
    testUsers.push(userId);
    await app.db.insert(schema.users).values({
      id: userId, email: `${userId}@example.invalid`, passwordHash: "test-only"
    });
    await app.db.insert(schema.devices).values({ id: deviceId, userId, name: "other" });
    const response = await app.inject({
      method: "POST", url: "/sync/pull", payload: { protocolVersion: syncProtocolVersion }
    });
    expect(response.statusCode, response.body).toBe(200);
    expect(response.json().records).toEqual([]);
    await push({ id: ids[0], type: "note", encryptedPayload: "eHl6", clientRevision: 1 });
    const original = await app.db.select().from(schema.encryptedRecords)
      .where(eq(schema.encryptedRecords.userId, ownerId));
    expect(original).toHaveLength(3);
    expect(original.every((r) => r.encryptedPayload.length === 500_000)).toBe(true);
  });
});
