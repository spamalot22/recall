import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";

export async function registerAuthenticateDecorator(app: FastifyInstance) {
  app.decorate("authenticate", async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.code(401).send({ error: "unauthorized" });
    }
  });
}
