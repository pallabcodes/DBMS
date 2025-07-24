require('dotenv').config();
const Redis = require('ioredis');
const RedisClustr = require('redis-clustr');
const fp = require('fastify-plugin');

// Redis Cluster Configuration
const clusterNodes = [
  { host: process.env.REDIS_HOST || '127.0.0.1', port: 6379 },
  { host: process.env.REDIS_HOST || '127.0.0.1', port: 6380 },
  { host: process.env.REDIS_HOST || '127.0.0.1', port: 6381 }
];

// Redis Connection Pool Configuration
const connectionPoolConfig = {
  min: 5,                    // minimum number of connections
  max: 100,                 // maximum number of connections
  acquireTimeoutMillis: 5000 // maximum time to acquire a connection
};

// Redis Cluster Options
const clusterOptions = {
  redisOptions: {
    password: process.env.REDIS_PASSWORD,
    tls: process.env.REDIS_TLS === 'true' ? {} : undefined,
    maxRetriesPerRequest: 3,
    enableReadyCheck: true,
    connectTimeout: 10000,
    disconnectTimeout: 2000,
    commandTimeout: 5000,
    retryStrategy(times) {
      const delay = Math.min(times * 50, 2000);
      return delay;
    },
    reconnectOnError(err) {
      const targetError = 'READONLY';
      if (err.message.includes(targetError)) {
        return true;
      }
      return false;
    }
  }
};

// Redis Sentinel Configuration (for high availability)
const sentinelConfig = process.env.REDIS_SENTINEL === 'true' ? {
  sentinels: [
    { host: process.env.SENTINEL_HOST_1, port: process.env.SENTINEL_PORT_1 },
    { host: process.env.SENTINEL_HOST_2, port: process.env.SENTINEL_PORT_2 },
    { host: process.env.SENTINEL_HOST_3, port: process.env.SENTINEL_PORT_3 }
  ],
  name: 'mymaster',
  password: process.env.REDIS_PASSWORD,
  connectTimeout: 10000,
  failoverRetryStrategy(times) {
    const delay = Math.min(times * 100, 3000);
    return delay;
  }
} : null;

// Create Redis client based on configuration
function createRedisClient() {
  if (process.env.REDIS_CLUSTER === 'true') {
    return new RedisClustr({
      servers: clusterNodes,
      ...clusterOptions
    });
  } else if (process.env.REDIS_SENTINEL === 'true') {
    return new Redis(sentinelConfig);
  } else {
    return new Redis({
      host: process.env.REDIS_HOST || '127.0.0.1',
      port: process.env.REDIS_PORT || 6379,
      password: process.env.REDIS_PASSWORD,
      ...clusterOptions.redisOptions
    });
  }
}

// Fastify plugin for Redis
async function redisPlugin(fastify, options) {
  const redis = createRedisClient();

  // Handle Redis events
  redis.on('connect', () => {
    fastify.log.info('Redis client connected');
  });

  redis.on('error', (err) => {
    fastify.log.error('Redis client error:', err);
  });

  redis.on('close', () => {
    fastify.log.warn('Redis connection closed');
  });

  redis.on('reconnecting', () => {
    fastify.log.info('Redis client reconnecting');
  });

  // Decorate Fastify instance with Redis client
  fastify.decorate('redis', redis);

  // Hook for cleanup on server close
  fastify.addHook('onClose', (instance, done) => {
    if (instance.redis) {
      instance.redis.quit();
    }
    done();
  });
}

module.exports = fp(redisPlugin, {
  name: 'fastify-redis-enterprise'
});
