const RedisEnterpriseService = require('../services/redis.enterprise.service');
const assert = require('assert');

async function runTests() {
  console.log('Starting Redis Enterprise Service Tests...\n');

  // Initialize Redis service with local container
  const redis = new RedisEnterpriseService({
    host: 'localhost',
    port: 6379,
    // If you have password set in your container, add it here
    // password: 'your-password'
  });

  try {
    // 1. Test Basic Operations
    console.log('Testing Basic Operations...');
    await testBasicOperations(redis);
    console.log('✅ Basic Operations: PASSED\n');

    // 2. Test Geo-indexing (Lyft-style)
    console.log('Testing Geo-indexing...');
    await testGeoIndexing(redis);
    console.log('✅ Geo-indexing: PASSED\n');

    // 3. Test Data Types
    console.log('Testing Redis Data Types...');
    await testDataTypes(redis);
    console.log('✅ Data Types: PASSED\n');

    // 4. Test Transactions
    console.log('Testing Transactions...');
    await testTransactions(redis);
    console.log('✅ Transactions: PASSED\n');

    // 5. Test PubSub
    console.log('Testing PubSub...');
    await testPubSub(redis);
    console.log('✅ PubSub: PASSED\n');

    // 6. Test Rate Limiting
    console.log('Testing Rate Limiting...');
    await testRateLimiting(redis);
    console.log('✅ Rate Limiting: PASSED\n');

    console.log('All tests passed successfully! 🎉');

  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

async function testBasicOperations(redis) {
  // Test SET with TTL
  await redis.set('test:key', { value: 'test' }, 60);
  const value = await redis.get('test:key');
  assert.deepStrictEqual(value, { value: 'test' });

  // Test batch operations
  await redis.batchSet([
    { key: 'batch:1', value: 'one' },
    { key: 'batch:2', value: 'two' }
  ]);
  const batch1 = await redis.get('batch:1');
  const batch2 = await redis.get('batch:2');
  assert.strictEqual(batch1, 'one');
  assert.strictEqual(batch2, 'two');
}

async function testGeoIndexing(redis) {
  // Add driver locations
  await redis.addDriverLocation('driver:1', 37.7749, -122.4194); // San Francisco
  await redis.addDriverLocation('driver:2', 37.7833, -122.4167); // Nearby SF

  // Find nearby drivers
  const nearbyDrivers = await redis.findNearbyDrivers(37.7749, -122.4194, 2);
  assert(nearbyDrivers.length >= 2);
}

async function testDataTypes(redis) {
  // Test Sorted Set
  await redis.addToSortedSet('scores', 100, 'player1');
  await redis.addToSortedSet('scores', 200, 'player2');
  const scores = await redis.getRangeFromSortedSet('scores', 0, -1);
  assert(scores.length === 4); // 2 members with their scores

  // Test Set
  await redis.addToSet('uniqueUsers', 'user1', 'user2');
  const users = await redis.getSetMembers('uniqueUsers');
  assert(users.length === 2);

  // Test Hash
  await redis.setHash('user:1', 'name', 'John');
  const name = await redis.getHashField('user:1', 'name');
  assert.strictEqual(name, 'John');

  // Test List
  await redis.pushToList('messages', 'msg1', 'msg2');
  const messages = await redis.getListRange('messages', 0, -1);
  assert(messages.length === 2);
}

async function testTransactions(redis) {
  const ops = [
    { command: 'set', key: 'tx:1', args: ['value1'] },
    { command: 'set', key: 'tx:2', args: ['value2'] }
  ];

  const results = await redis.executeTransaction(ops);
  assert(results.length === 2);
  
  const value1 = await redis.get('tx:1');
  const value2 = await redis.get('tx:2');
  assert.strictEqual(value1, 'value1');
  assert.strictEqual(value2, 'value2');
}

async function testPubSub(redis) {
  return new Promise(async (resolve) => {
    const testMessage = { event: 'test', data: 'message' };
    
    // Subscribe
    const subscriber = redis.subscribe('test:channel', (message) => {
      assert.deepStrictEqual(message, testMessage);
      subscriber.unsubscribe();
      resolve();
    });

    // Publish after short delay
    setTimeout(async () => {
      await redis.publish('test:channel', testMessage);
    }, 100);
  });
}

async function testRateLimiting(redis) {
  const key = 'rate:test';
  const limit = 5;
  const window = 1; // 1 second

  // Should allow up to 5 requests
  for (let i = 0; i < 5; i++) {
    const allowed = await redis.slidingWindowRateLimit(key, limit, window);
    assert(allowed);
  }

  // 6th request should be denied
  const denied = await redis.slidingWindowRateLimit(key, limit, window);
  assert(!denied);
}

// Run the tests
runTests();
