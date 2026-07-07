import type { FastifyReply, FastifyRequest } from "fastify";
import type { NodePgDatabase } from "drizzle-orm/node-postgres";
import type pg from "pg";

import type * as schema from "../db/schema.js";

declare module "fastify" {
  interface FastifyInstance {
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<unknown>;
    db: NodePgDatabase<typeof schema>;
    pgPool: pg.Pool;
  }
}

declare module "@fastify/jwt" {
  interface FastifyJWT {
    payload: {
      userId: string;
      sessionId: string;
      deviceId: string;
    };
    user: {
      userId: string;
      sessionId: string;
      deviceId: string;
    };
  }
}
