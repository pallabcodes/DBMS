const Fastify = require('fastify');
const RedisEnterpriseService = require('../services/redis.enterprise.service');

async function buildRideHailingService() {
  const fastify = Fastify({ logger: true });

  // Initialize Redis with cluster configuration
  const redis = new RedisEnterpriseService({
    mode: 'cluster',
    nodes: [
      { host: 'redis-1', port: 6379 },
      { host: 'redis-2', port: 6379 },
      { host: 'redis-3', port: 6379 }
    ],
    maxPoolSize: 100
  });

  // Driver location management (Lyft-style)
  fastify.post('/drivers/:id/location', async (request, reply) => {
    const { id } = request.params;
    const { lat, lng } = request.body;

    // Start transaction
    const multi = redis.redis.multi();
    
    try {
      // Add to geo index
      await redis.addDriverLocation(id, lat, lng);
      
      // Update driver status in hash
      await redis.setHash(`driver:{${id}}:status`, 'location', JSON.stringify({ lat, lng }));
      
      // Publish location update
      await redis.publish('driver_updates', { id, lat, lng });
      
      return { success: true };
    } catch (error) {
      fastify.log.error(error);
      return reply.code(500).send({ error: 'Failed to update location' });
    }
  });

  // Rider matching with nearby drivers
  fastify.get('/riders/:id/nearby-drivers', async (request, reply) => {
    const { lat, lng } = request.query;
    const radius = request.query.radius || 2; // km

    try {
      // Find nearby drivers using geo index
      const drivers = await redis.findNearbyDrivers(lat, lng, radius);
      
      // Get additional driver info using pipelining
      const pipeline = redis.redis.pipeline();
      drivers.forEach(([driverId]) => {
        pipeline.hgetall(`driver:{${driverId}}:info`);
      });
      
      const driverInfo = await pipeline.exec();
      
      // Combine location and driver info
      const enrichedDrivers = drivers.map(([driverId, [lng, lat]], index) => ({
        id: driverId,
        location: { lat, lng },
        info: driverInfo[index][1]
      }));

      return enrichedDrivers;
    } catch (error) {
      fastify.log.error(error);
      return reply.code(500).send({ error: 'Failed to find nearby drivers' });
    }
  });

  // Real-time driver tracking with PubSub
  fastify.get('/drivers/:id/track', { websocket: true }, (connection, req) => {
    const { id } = req.params;
    
    // Subscribe to driver updates
    const subscriber = redis.subscribe('driver_updates', (message) => {
      if (message.id === id) {
        connection.socket.send(JSON.stringify(message));
      }
    });

    connection.socket.on('close', () => {
      subscriber.unsubscribe();
    });
  });

  // Search drivers by attributes using RediSearch
  fastify.get('/drivers/search', async (request, reply) => {
    const { query } = request.query;

    try {
      const results = await redis.search('drivers_idx', query);
      return results;
    } catch (error) {
      fastify.log.error(error);
      return reply.code(500).send({ error: 'Search failed' });
    }
  });

  // Route optimization using RedisGraph
  fastify.post('/routes/optimize', async (request, reply) => {
    const { start, end, constraints } = request.body;

    try {
      const query = `
        MATCH (start:Location {id: $start})
        MATCH (end:Location {id: $end})
        MATCH path = shortestPath((start)-[:ROAD*]->(end))
        RETURN path
      `;

      const route = await redis.executeGraphQuery('routes', query, { start, end });
      return route;
    } catch (error) {
      fastify.log.error(error);
      return reply.code(500).send({ error: 'Route optimization failed' });
    }
  });

  // ML-based pricing using RedisAI
  fastify.post('/rides/estimate', async (request, reply) => {
    const { distance, time, demand } = request.body;

    try {
      const prediction = await redis.runInference('pricing_model', [
        distance, time, demand
      ]);
      return { price: prediction };
    } catch (error) {
      fastify.log.error(error);
      return reply.code(500).send({ error: 'Price estimation failed' });
    }
  });

  return fastify;
}

module.exports = buildRideHailingService;
