const { promisify } = require('util');
const { performance } = require('perf_hooks');

class RedisService {
  constructor(redis) {
    this.redis = redis;
    this.pipeline = redis.pipeline();
  }

  /**
   * Enhanced set operation with automatic serialization and TTL
   * @param {string} key - The key to set
   * @param {any} value - The value to store
   * @param {number} ttl - Time to live in seconds
   * @returns {Promise<void>}
   */
  async set(key, value, ttl = 3600) {
    try {
      const serializedValue = JSON.stringify(value);
      const startTime = performance.now();
      
      if (ttl) {
        await this.redis.set(key, serializedValue, 'EX', ttl);
      } else {
        await this.redis.set(key, serializedValue);
      }

      const duration = performance.now() - startTime;
      if (duration > 100) { // Log slow operations
        console.warn(`Slow Redis SET operation: ${duration}ms for key ${key}`);
      }
    } catch (error) {
      console.error('Redis SET error:', error);
      throw error;
    }
  }

  /**
   * Batch set operations using pipelining
   * @param {Array<{key: string, value: any, ttl?: number}>} items 
   * @returns {Promise<void>}
   */
  async batchSet(items) {
    const pipeline = this.redis.pipeline();
    
    for (const item of items) {
      const serializedValue = JSON.stringify(item.value);
      if (item.ttl) {
        pipeline.set(item.key, serializedValue, 'EX', item.ttl);
      } else {
        pipeline.set(item.key, serializedValue);
      }
    }

    await pipeline.exec();
  }

  /**
   * Get value with automatic deserialization and error handling
   * @param {string} key 
   * @returns {Promise<any>}
   */
  async get(key) {
    try {
      const startTime = performance.now();
      const value = await this.redis.get(key);
      const duration = performance.now() - startTime;

      if (duration > 50) { // Log slow reads
        console.warn(`Slow Redis GET operation: ${duration}ms for key ${key}`);
      }

      return value ? JSON.parse(value) : null;
    } catch (error) {
      console.error('Redis GET error:', error);
      throw error;
    }
  }

  /**
   * Delete with UNLINK for large keys
   * @param {string} key 
   * @returns {Promise<void>}
   */
  async delete(key) {
    try {
      await this.redis.unlink(key);
    } catch (error) {
      console.error('Redis DELETE error:', error);
      throw error;
    }
  }

  /**
   * Atomic increment with error handling
   * @param {string} key 
   * @returns {Promise<number>}
   */
  async increment(key) {
    try {
      return await this.redis.incr(key);
    } catch (error) {
      console.error('Redis INCREMENT error:', error);
      throw error;
    }
  }

  /**
   * Implement rate limiting using Redis
   * @param {string} key - The rate limit key
   * @param {number} limit - Maximum number of requests
   * @param {number} window - Time window in seconds
   * @returns {Promise<boolean>}
   */
  async checkRateLimit(key, limit, window) {
    const current = await this.redis.incr(key);
    if (current === 1) {
      await this.redis.expire(key, window);
    }
    return current <= limit;
  }

  /**
   * Implements distributed locking pattern
   * @param {string} lockKey - The lock key
   * @param {number} ttl - Lock timeout in milliseconds
   * @returns {Promise<string|null>} Lock token if acquired, null if not
   */
  async acquireLock(lockKey, ttl = 10000) {
    const token = Math.random().toString(36).substring(2);
    const acquired = await this.redis.set(
      `lock:${lockKey}`,
      token,
      'PX',
      ttl,
      'NX'
    );
    return acquired ? token : null;
  }

  /**
   * Release distributed lock
   * @param {string} lockKey - The lock key
   * @param {string} token - The lock token
   * @returns {Promise<boolean>}
   */
  async releaseLock(lockKey, token) {
    const script = `
      if redis.call("get", KEYS[1]) == ARGV[1] then
        return redis.call("del", KEYS[1])
      else
        return 0
      end
    `;
    const result = await this.redis.eval(
      script,
      1,
      `lock:${lockKey}`,
      token
    );
    return result === 1;
  }

  /**
   * Implements sliding window rate limiting
   * @param {string} key - The rate limit key
   * @param {number} limit - Maximum number of requests
   * @param {number} window - Time window in seconds
   * @returns {Promise<boolean>}
   */
  async slidingWindowRateLimit(key, limit, window) {
    const now = Date.now();
    const windowStart = now - (window * 1000);

    const multi = this.redis.multi();
    multi.zadd(key, now, now.toString());
    multi.zremrangebyscore(key, '-inf', windowStart);
    multi.zcard(key);
    multi.expire(key, window);
    
    const results = await multi.exec();
    const count = results[2][1];
    
    return count <= limit;
  }

  /**
   * Implements caching with automatic refresh
   * @param {string} key - Cache key
   * @param {number} ttl - TTL in seconds
   * @param {Function} fetchData - Function to fetch fresh data
   * @returns {Promise<any>}
   */
  async getCacheWithRefresh(key, ttl, fetchData) {
    let data = await this.get(key);
    
    if (!data) {
      data = await fetchData();
      await this.set(key, data, ttl);
    }

    // Refresh cache in background if approaching expiry
    const ttlRemaining = await this.redis.ttl(key);
    if (ttlRemaining < ttl * 0.2) { // Refresh if less than 20% TTL remains
      setImmediate(async () => {
        const freshData = await fetchData();
        await this.set(key, freshData, ttl);
      });
    }

    return data;
  }
}

module.exports = RedisService;
