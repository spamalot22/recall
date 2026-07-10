import {
  boolean,
  index,
  integer,
  jsonb,
  pgEnum,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uniqueIndex,
  uuid
} from "drizzle-orm/pg-core";

export const auditAction = pgEnum("audit_action", [
  "bootstrap_user_created",
  "login_succeeded",
  "login_failed",
  "refresh_rotated",
  "logout",
  "session_revoked",
  "key_bundle_updated",
  "sync_push",
  "sync_pull"
]);

export const encryptedRecordType = pgEnum("encrypted_record_type", [
  "note",
  "checklist_item",
  "reminder",
  "reminder_occurrence",
  "tombstone"
]);

export const users = pgTable(
  "users",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    email: text("email").notNull(),
    passwordHash: text("password_hash").notNull(),
    isAdmin: boolean("is_admin").notNull().default(false),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    emailUnique: uniqueIndex("users_email_unique").on(table.email)
  })
);

export const devices = pgTable(
  "devices",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    name: text("name").notNull(),
    publicKey: text("public_key"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    lastSeenAt: timestamp("last_seen_at", { withTimezone: true })
  },
  (table) => ({
    userIdx: index("devices_user_id_idx").on(table.userId)
  })
);

export const sessions = pgTable(
  "sessions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    deviceId: uuid("device_id").notNull().references(() => devices.id, { onDelete: "cascade" }),
    refreshTokenHash: text("refresh_token_hash").notNull(),
    refreshTokenVersion: integer("refresh_token_version").notNull().default(1),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    revokedAt: timestamp("revoked_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    userIdx: index("sessions_user_id_idx").on(table.userId),
    deviceIdx: index("sessions_device_id_idx").on(table.deviceId)
  })
);

export const keyBundles = pgTable(
  "key_bundles",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    passwordWrappedMasterKey: text("password_wrapped_master_key").notNull(),
    recoveryWrappedMasterKey: text("recovery_wrapped_master_key").notNull(),
    recoveryVerifier: text("recovery_verifier"),
    kdfParams: jsonb("kdf_params").notNull(),
    version: integer("version").notNull().default(1),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    userUnique: uniqueIndex("key_bundles_user_id_unique").on(table.userId)
  })
);

export const encryptedRecords = pgTable(
  "encrypted_records",
  {
    id: uuid("id").notNull(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    type: encryptedRecordType("type").notNull(),
    encryptedPayload: text("encrypted_payload").notNull(),
    payloadVersion: integer("payload_version").notNull().default(1),
    clientRevision: integer("client_revision").notNull(),
    serverRevision: integer("server_revision").notNull(),
    sourceDeviceId: uuid("source_device_id").references(() => devices.id, { onDelete: "set null" }),
    conflictOfRecordId: uuid("conflict_of_record_id"),
    deletedAt: timestamp("deleted_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    primaryKey: primaryKey({
      columns: [table.userId, table.id],
      name: "encrypted_records_user_id_id_pk"
    }),
    userRevisionUnique: uniqueIndex("encrypted_records_user_revision_unique").on(table.userId, table.serverRevision),
    userRevisionIdx: index("encrypted_records_user_revision_idx").on(table.userId, table.serverRevision),
    userTypeIdx: index("encrypted_records_user_type_idx").on(table.userId, table.type)
  })
);

export const syncCursors = pgTable(
  "sync_cursors",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    deviceId: uuid("device_id").notNull().references(() => devices.id, { onDelete: "cascade" }),
    lastServerRevision: integer("last_server_revision").notNull().default(0),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    deviceUnique: uniqueIndex("sync_cursors_device_id_unique").on(table.deviceId),
    userIdx: index("sync_cursors_user_id_idx").on(table.userId)
  })
);

export const auditEvents = pgTable(
  "audit_events",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => users.id, { onDelete: "set null" }),
    deviceId: uuid("device_id").references(() => devices.id, { onDelete: "set null" }),
    action: auditAction("action").notNull(),
    ipAddress: text("ip_address"),
    userAgent: text("user_agent"),
    metadata: jsonb("metadata"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    userCreatedIdx: index("audit_events_user_created_idx").on(table.userId, table.createdAt)
  })
);
