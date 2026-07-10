import { and, eq, gt, isNull } from "drizzle-orm";
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";

import { sessions } from "../db/schema.js";

export async function registerAuthenticateDecorator(app: FastifyInstance) {
  app.decorate("authenticate", async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.code(401).send({ error: "unauthorized" });
    }

    const [session] = await app.db
      .select({ id: sessions.id })
      .from(sessions)
      .where(
        and(
          eq(sessions.id, request.user.sessionId),
          eq(sessions.userId, request.user.userId),
          eq(sessions.deviceId, request.user.deviceId),
          isNull(sessions.revokedAt),
          gt(sessions.expiresAt, new Date())
        )
      )
      .limit(1);

    if (!session) {
      return reply.code(401).send({ error: "unauthorized" });
    }
  });
}
