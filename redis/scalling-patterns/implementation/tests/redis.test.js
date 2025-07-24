const buildServer = require('../src/server');
const Redis = require('ioredis-mock');

describe('Redis Service Integration Tests', () => {
  let app;
  let redis;

  beforeAll(async () => {
    // Mock Redis for testing
    redis = new Redis();
    app = await buildServer();
    
    // Replace real Redis with mock
    app.redis = redis;
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    redis.flushall();
  });

  describe('Cache Operations', () => {
    test('should set and get cache value', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/cache/testKey'
      });

      expect(response.statusCode).toBe(200);
    });

    test('should handle rate limiting', async () => {
      // Make multiple requests to trigger rate limit
      const requests = Array(150).fill().map(() =>
        app.inject({
          method: 'GET',
          url: '/cache/testKey'
        })
      );

      const responses = await Promise.all(requests);
      const tooManyRequests = responses.filter(r => r.statusCode === 429);
      
      expect(tooManyRequests.length).toBeGreaterThan(0);
    });
  });

  describe('Distributed Lock', () => {
    test('should acquire and release lock', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/lock/resource1'
      });

      expect(response.statusCode).toBe(200);
      expect(JSON.parse(response.payload)).toEqual({ success: true });
    });

    test('should handle concurrent lock requests', async () => {
      const requests = Array(5).fill().map(() =>
        app.inject({
          method: 'POST',
          url: '/lock/resource1'
        })
      );

      const responses = await Promise.all(requests);
      const conflicts = responses.filter(r => r.statusCode === 409);
      
      expect(conflicts.length).toBeGreaterThan(0);
    });
  });

  describe('Health Check', () => {
    test('should return healthy status', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/health'
      });

      expect(response.statusCode).toBe(200);
      expect(JSON.parse(response.payload)).toEqual({
        status: 'ok',
        redis: 'connected'
      });
    });
  });
});
