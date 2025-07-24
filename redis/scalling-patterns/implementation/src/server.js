const fastify = require('fastify')({
  logger: {
    level: process.env.LOG_LEVEL || 'info',
    serializers: {
      req(request) {
        return {
          method: request.method,
          url: request.url,
          hostname: request.hostname,
          remoteAddress: request.ip,
          remotePort: request.socket ? request.socket.remotePort : undefined
        };
      }
    }
  }
});

// Import plugins
const cors = require('@fastify/cors');
const helmet = require('@fastify/helmet');
const rateLimit = require('@fastify/rate-limit');
const metrics = require('fastify-metrics');

// Import Redis configuration
const redisPlugin = require('./config/redis');
const RedisService = require('./services/redis.service');

async function buildServer() {
  try {
    // Register plugins
    await fastify.register(cors, {
      origin: process.env.CORS_ORIGIN || false
    });

    await fastify.register(helmet, {
      global: true
    });

    await fastify.register(rateLimit, {
      max: 100,
      timeWindow: '1 minute'
    });

    await fastify.register(metrics, {
      endpoint: '/metrics'
    });

    // Register Redis plugin
    await fastify.register(redisPlugin);

    // Create Redis service instance
    const redisService = new RedisService(fastify.redis);
    fastify.decorate('redisService', redisService);

    // Health check route
    fastify.get('/health', async (request, reply) => {
      try {
        await fastify.redis.ping();
        return { status: 'ok', redis: 'connected' };
      } catch (error) {
        fastify.log.error('Health check failed:', error);
        return reply.code(503).send({
          status: 'error',
          message: 'Redis connection failed'
        });
      }
    });

    // Example cache route with rate limiting
    fastify.get('/cache/:key', {
      schema: {
        params: {
          type: 'object',
          properties: {
            key: { type: 'string' }
          }
        }
      },
      handler: async (request, reply) => {
        const { key } = request.params;
        
        // Check rate limit
        const isAllowed = await redisService.slidingWindowRateLimit(
          `ratelimit:${request.ip}`, 
          100, 
          60
        );
        
        if (!isAllowed) {
          return reply.code(429).send({
            error: 'Too Many Requests'
          });
        }

        try {
          const value = await redisService.get(key);
          return { key, value };
        } catch (error) {
          fastify.log.error('Cache get error:', error);
          return reply.code(500).send({
            error: 'Internal Server Error'
          });
        }
      }
    });

    // Example distributed lock route
    fastify.post('/lock/:resource', {
      schema: {
        params: {
          type: 'object',
          properties: {
            resource: { type: 'string' }
          }
        }
      },
      handler: async (request, reply) => {
        const { resource } = request.params;
        
        try {
          const token = await redisService.acquireLock(resource);
          if (!token) {
            return reply.code(409).send({
              error: 'Resource is locked'
            });
          }

          // Simulate some work
          await new Promise(resolve => setTimeout(resolve, 1000));

          // Release the lock
          await redisService.releaseLock(resource, token);
          
          return { success: true };
        } catch (error) {
          fastify.log.error('Lock error:', error);
          return reply.code(500).send({
            error: 'Internal Server Error'
          });
        }
      }
    });

    // Register error handler
    fastify.setErrorHandler((error, request, reply) => {
      fastify.log.error(error);
      reply.code(500).send({ error: 'Internal Server Error' });
    });

    return fastify;
  } catch (error) {
    console.error('Error building server:', error);
    process.exit(1);
  }
}

async function startServer() {
  try {
    const server = await buildServer();
    await server.listen({
      port: process.env.PORT || 3000,
      host: process.env.HOST || '0.0.0.0'
    });
  } catch (error) {
    console.error('Error starting server:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  startServer();
}

module.exports = buildServer;
