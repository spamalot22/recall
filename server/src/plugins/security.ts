import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import jwt from "@fastify/jwt";
import rateLimit from "@fastify/rate-limit";
import type { FastifyInstance } from "fastify";

import type { AppConfig } from "../config.js";

export async function registerSecurityPlugins(app: FastifyInstance, config: AppConfig) {
  await app.register(helmet);

  await app.register(cors, {
    origin: false
  });

  await app.register(rateLimit, {
    max: 100,
    timeWindow: "1 minute"
  });

  await app.register(jwt, {
    secret: config.JWT_ACCESS_SECRET
  });
}
