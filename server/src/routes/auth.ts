import { and, eq, gt, isNull, sql } from "drizzle-orm";
import type { FastifyInstance } from "fastify";
import { timingSafeEqual } from "node:crypto";
import { z } from "zod";

import type { AppConfig } from "../config.js";
import { auditEvents, devices, keyBundles, sessions, users } from "../db/schema.js";
import { hashPassword, verifyPassword } from "../auth/passwords.js";
import { createRefreshToken, hashRefreshToken } from "../auth/tokens.js";
import { keyBundleInputSchema, recoveryVerifierSchema } from "../security/key-bundle-schema.js";

const accessTokenTtl = "15m";
const refreshTokenDays = 30;
const strictAuthRateLimit = { max: 5, timeWindow: "1 minute" } as const;
const refreshRateLimit = { max: 20, timeWindow: "1 minute" } as const;

const loginSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(1).max(1024),
  deviceName: z.string().trim().min(1).max(120)
});

const registerSchema = loginSchema.extend({ password: z.string().min(12).max(1024) }).and(keyBundleInputSchema);

const recoveryBundleSchema = z.object({
  email: z.string().trim().email().max(254),
  recoveryVerifier: recoveryVerifierSchema
});

const recoverSchema = recoveryBundleSchema.extend({
  newPassword: z.string().min(12).max(1024),
  deviceName: z.string().trim().min(1).max(120),
}).and(keyBundleInputSchema);

const refreshSchema = z.object({
  refreshToken: z.string().regex(/^[A-Za-z0-9_-]{43}$/)
});

function refreshExpiry() {
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + refreshTokenDays);
  return expiresAt;
}

export function recoveryVerifierMatches(stored: string | null, provided: string) {
  if (!stored) {
    return false;
  }
  const storedBytes = Buffer.from(stored, "utf8");
  const providedBytes = Buffer.from(provided, "utf8");
  return storedBytes.length === providedBytes.length && timingSafeEqual(storedBytes, providedBytes);
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
  const dummyPasswordHash = await hashPassword(createRefreshToken());

  app.post("/auth/register", { config: { rateLimit: strictAuthRateLimit } }, async (request, reply) => {
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
        recoveryVerifier: input.recoveryVerifier,
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

  app.post("/auth/recovery-bundle", { config: { rateLimit: strictAuthRateLimit } }, async (request, reply) => {
    const input = recoveryBundleSchema.parse(request.body);
    const email = input.email.toLowerCase();
    const [user] = await app.db.select({ id: users.id }).from(users).where(eq(users.email, email)).limit(1);
    const [bundle] = user
      ? await app.db.select().from(keyBundles).where(eq(keyBundles.userId, user.id)).limit(1)
      : [];

    if (!bundle || !recoveryVerifierMatches(bundle.recoveryVerifier, input.recoveryVerifier)) {
      await insertAudit(app, {
        action: "login_failed",
        requestIp: request.ip,
        userAgent: request.headers["user-agent"],
        metadata: { recovery: true }
      });
      return reply.code(401).send({ error: "invalid_recovery_key" });
    }

    return {
      userId: user.id,
      keyBundle: {
        passwordWrappedMasterKey: bundle.passwordWrappedMasterKey,
        recoveryWrappedMasterKey: bundle.recoveryWrappedMasterKey,
        kdfParams: bundle.kdfParams,
        version: bundle.version
      }
    };
  });

  app.post("/auth/recover", { config: { rateLimit: strictAuthRateLimit } }, async (request, reply) => {
    const input = recoverSchema.parse(request.body);
    const email = input.email.toLowerCase();
    const [user] = await app.db.select().from(users).where(eq(users.email, email)).limit(1);
    const [bundle] = user
      ? await app.db.select().from(keyBundles).where(eq(keyBundles.userId, user.id)).limit(1)
      : [];

    if (!user || !bundle || !recoveryVerifierMatches(bundle.recoveryVerifier, input.recoveryVerifier)) {
      return reply.code(401).send({ error: "invalid_recovery_key" });
    }

    const passwordHash = await hashPassword(input.newPassword);
    const refreshToken = createRefreshToken();
    const now = new Date();
    const result = await app.db.transaction(async (tx) => {
      await tx.update(users).set({ passwordHash, updatedAt: now }).where(eq(users.id, user.id));
      await tx
        .update(keyBundles)
        .set({
          passwordWrappedMasterKey: input.passwordWrappedMasterKey,
          recoveryWrappedMasterKey: input.recoveryWrappedMasterKey,
          recoveryVerifier: input.recoveryVerifier,
          kdfParams: input.kdfParams,
          version: input.version,
          updatedAt: now
        })
        .where(eq(keyBundles.id, bundle.id));
      await tx.update(sessions).set({ revokedAt: now, updatedAt: now }).where(eq(sessions.userId, user.id));

      const [device] = await tx
        .insert(devices)
        .values({ userId: user.id, name: input.deviceName, lastSeenAt: now })
        .returning({ id: devices.id, name: devices.name });
      const [session] = await tx
        .insert(sessions)
        .values({
          userId: user.id,
          deviceId: device.id,
          refreshTokenHash: hashRefreshToken(refreshToken, config.JWT_REFRESH_SECRET),
          expiresAt: refreshExpiry()
        })
        .returning({ id: sessions.id, expiresAt: sessions.expiresAt });
      return { device, session };
    });

    const accessToken = app.jwt.sign(
      { userId: user.id, sessionId: result.session.id, deviceId: result.device.id },
      { expiresIn: accessTokenTtl }
    );
    await insertAudit(app, {
      action: "login_succeeded",
      userId: user.id,
      deviceId: result.device.id,
      requestIp: request.ip,
      userAgent: request.headers["user-agent"],
      metadata: { recovery: true }
    });

    return reply.send({
      accessToken,
      refreshToken,
      refreshTokenExpiresAt: result.session.expiresAt.toISOString(),
      device: result.device,
      user: { id: user.id, email: user.email, isAdmin: user.isAdmin }
    });
  });

  app.post("/auth/login", { config: { rateLimit: strictAuthRateLimit } }, async (request, reply) => {
    const input = loginSchema.parse(request.body);
    const email = input.email.toLowerCase();
    const [user] = await app.db.select().from(users).where(eq(users.email, email)).limit(1);

    const passwordValid = await verifyPassword(user?.passwordHash ?? dummyPasswordHash, input.password);
    if (!user || !passwordValid) {
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

  app.post("/auth/refresh", { config: { rateLimit: refreshRateLimit } }, async (request, reply) => {
    const input = refreshSchema.parse(request.body);
    const refreshTokenHash = hashRefreshToken(input.refreshToken, config.JWT_REFRESH_SECRET);
    const nextRefreshToken = createRefreshToken();
    const expiresAt = refreshExpiry();
    const [session] = await app.db
      .update(sessions)
      .set({
        refreshTokenHash: hashRefreshToken(nextRefreshToken, config.JWT_REFRESH_SECRET),
        refreshTokenVersion: sql`${sessions.refreshTokenVersion} + 1`,
        expiresAt,
        updatedAt: new Date()
      })
      .where(
        and(
          eq(sessions.refreshTokenHash, refreshTokenHash),
          isNull(sessions.revokedAt),
          gt(sessions.expiresAt, new Date())
        )
      )
      .returning({
        id: sessions.id,
        userId: sessions.userId,
        deviceId: sessions.deviceId,
        expiresAt: sessions.expiresAt
      });

    if (!session) {
      return reply.code(401).send({ error: "invalid_refresh_token" });
    }

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
      refreshTokenExpiresAt: session.expiresAt.toISOString()
    });
  });

  app.post("/auth/logout", { config: { rateLimit: refreshRateLimit } }, async (request, reply) => {
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
