import { and, eq, gt, isNull } from "drizzle-orm";
import type { FastifyInstance } from "fastify";
import { z } from "zod";

import type { AppConfig } from "../config.js";
import { auditEvents, devices, keyBundles, sessions, users } from "../db/schema.js";
import { hashPassword, verifyPassword } from "../auth/passwords.js";
import { createRefreshToken, hashRefreshToken } from "../auth/tokens.js";

const accessTokenTtl = "15m";
const refreshTokenDays = 30;

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
  deviceName: z.string().trim().min(1).max(120)
});

const registerSchema = loginSchema.extend({
  recoveryWrappedMasterKey: z.string().min(1),
  passwordWrappedMasterKey: z.string().min(1),
  kdfParams: z.record(z.string(), z.unknown())
});

const refreshSchema = z.object({
  refreshToken: z.string().min(32)
});

function refreshExpiry() {
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + refreshTokenDays);
  return expiresAt;
}

async function insertAudit(
  app: FastifyInstance,
  input: {
    action: typeof auditEvents.$inferInsert.action;
    userId?: string;
    deviceId?: string;
    requestIp?: string;
    userAgent?: string;
    metadata?: Record<string, unknown>;
  }
) {
  await app.db.insert(auditEvents).values({
    action: input.action,
    userId: input.userId,
    deviceId: input.deviceId,
    ipAddress: input.requestIp,
    userAgent: input.userAgent,
    metadata: input.metadata
  });
}

export async function authRoutes(app: FastifyInstance, config: AppConfig) {
  app.post("/auth/register", async (request, reply) => {
    if (!config.PUBLIC_REGISTRATION_ENABLED) {
      return reply.code(403).send({ error: "registration_disabled" });
    }

    const input = registerSchema.parse(request.body);
    const email = input.email.toLowerCase();

    const [existing] = await app.db.select({ id: users.id }).from(users).where(eq(users.email, email)).limit(1);
    if (existing) {
      return reply.code(409).send({ error: "email_already_registered" });
    }

    const passwordHash = await hashPassword(input.password);
    const refreshToken = createRefreshToken();

    const { user, device, session } = await app.db.transaction(async (tx) => {
      const [createdUser] = await tx
        .insert(users)
        .values({
          email,
          passwordHash,
          isAdmin: false
        })
        .returning({ id: users.id, email: users.email, isAdmin: users.isAdmin });

      await tx.insert(keyBundles).values({
        userId: createdUser.id,
        passwordWrappedMasterKey: input.passwordWrappedMasterKey,
        recoveryWrappedMasterKey: input.recoveryWrappedMasterKey,
        kdfParams: input.kdfParams
      });

      const [createdDevice] = await tx
        .insert(devices)
        .values({
          userId: createdUser.id,
          name: input.deviceName,
          lastSeenAt: new Date()
        })
        .returning({ id: devices.id, name: devices.name });

      const [createdSession] = await tx
        .insert(sessions)
        .values({
          userId: createdUser.id,
          deviceId: createdDevice.id,
          refreshTokenHash: hashRefreshToken(refreshToken, config.JWT_REFRESH_SECRET),
          expiresAt: refreshExpiry()
        })
        .returning({ id: sessions.id, expiresAt: sessions.expiresAt });

      return {
        user: createdUser,
        device: createdDevice,
        session: createdSession
      };
    });

    const accessToken = app.jwt.sign(
      { userId: user.id, sessionId: session.id, deviceId: device.id },
      { expiresIn: accessTokenTtl }
    );

    await insertAudit(app, {
      action: "login_succeeded",
      userId: user.id,
      deviceId: device.id,
      requestIp: request.ip,
      userAgent: request.headers["user-agent"],
      metadata: { registration: true }
    });

    return reply.code(201).send({
      accessToken,
      refreshToken,
      refreshTokenExpiresAt: session.expiresAt.toISOString(),
      device,
      user
    });
  });

  app.post("/auth/login", async (request, reply) => {
    const input = loginSchema.parse(request.body);
    const email = input.email.toLowerCase();
    const [user] = await app.db.select().from(users).where(eq(users.email, email)).limit(1);

    if (!user || !(await verifyPassword(user.passwordHash, input.password))) {
      await insertAudit(app, {
        action: "login_failed",
        requestIp: request.ip,
        userAgent: request.headers["user-agent"],
        metadata: { email }
      });
      return reply.code(401).send({ error: "invalid_credentials" });
    }

    const [device] = await app.db
      .insert(devices)
      .values({
        userId: user.id,
        name: input.deviceName,
        lastSeenAt: new Date()
      })
      .returning({ id: devices.id, name: devices.name });

    const refreshToken = createRefreshToken();
    const [session] = await app.db
      .insert(sessions)
      .values({
        userId: user.id,
        deviceId: device.id,
        refreshTokenHash: hashRefreshToken(refreshToken, config.JWT_REFRESH_SECRET),
        expiresAt: refreshExpiry()
      })
      .returning({ id: sessions.id, expiresAt: sessions.expiresAt });

    const accessToken = app.jwt.sign(
      { userId: user.id, sessionId: session.id, deviceId: device.id },
      { expiresIn: accessTokenTtl }
    );

    await insertAudit(app, {
      action: "login_succeeded",
      userId: user.id,
      deviceId: device.id,
      requestIp: request.ip,
      userAgent: request.headers["user-agent"]
    });

    return reply.send({
      accessToken,
      refreshToken,
      refreshTokenExpiresAt: session.expiresAt.toISOString(),
      device,
      user: {
        id: user.id,
        email: user.email,
        isAdmin: user.isAdmin
      }
    });
  });

  app.post("/auth/refresh", async (request, reply) => {
    const input = refreshSchema.parse(request.body);
    const refreshTokenHash = hashRefreshToken(input.refreshToken, config.JWT_REFRESH_SECRET);
    const [session] = await app.db
      .select()
      .from(sessions)
      .where(
        and(
          eq(sessions.refreshTokenHash, refreshTokenHash),
          isNull(sessions.revokedAt),
          gt(sessions.expiresAt, new Date())
        )
      )
      .limit(1);

    if (!session) {
      return reply.code(401).send({ error: "invalid_refresh_token" });
    }

    const nextRefreshToken = createRefreshToken();
    const [updated] = await app.db
      .update(sessions)
      .set({
        refreshTokenHash: hashRefreshToken(nextRefreshToken, config.JWT_REFRESH_SECRET),
        refreshTokenVersion: session.refreshTokenVersion + 1,
        expiresAt: refreshExpiry(),
        updatedAt: new Date()
      })
      .where(eq(sessions.id, session.id))
      .returning({ id: sessions.id, expiresAt: sessions.expiresAt });

    const accessToken = app.jwt.sign(
      { userId: session.userId, sessionId: session.id, deviceId: session.deviceId },
      { expiresIn: accessTokenTtl }
    );

    await insertAudit(app, {
      action: "refresh_rotated",
      userId: session.userId,
      deviceId: session.deviceId,
      requestIp: request.ip,
      userAgent: request.headers["user-agent"]
    });

    return reply.send({
      accessToken,
      refreshToken: nextRefreshToken,
      refreshTokenExpiresAt: updated.expiresAt.toISOString()
    });
  });

  app.post("/auth/logout", async (request, reply) => {
    const input = refreshSchema.parse(request.body);
    const refreshTokenHash = hashRefreshToken(input.refreshToken, config.JWT_REFRESH_SECRET);
    const [session] = await app.db
      .update(sessions)
      .set({ revokedAt: new Date(), updatedAt: new Date() })
      .where(eq(sessions.refreshTokenHash, refreshTokenHash))
      .returning({ userId: sessions.userId, deviceId: sessions.deviceId });

    if (session) {
      await insertAudit(app, {
        action: "logout",
        userId: session.userId,
        deviceId: session.deviceId,
        requestIp: request.ip,
        userAgent: request.headers["user-agent"]
      });
    }

    return reply.code(204).send();
  });

  app.get("/auth/me", { preHandler: [app.authenticate] }, async (request) => {
    const userId = request.user.userId;
    const [user] = await app.db
      .select({ id: users.id, email: users.email, isAdmin: users.isAdmin })
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);

    return { user };
  });
}
