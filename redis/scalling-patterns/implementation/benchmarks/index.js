const autocannon = require('autocannon');
const { promisify } = require('util');
const { writeFileSync } = require('fs');

async function runBenchmark() {
  const results = await promisify(autocannon)({
    url: 'http://localhost:3000',
    connections: 100,
    duration: 30,
    pipelining: 10,
    timeout: 10,
    requests: [
      {
        method: 'GET',
        path: '/cache/benchmark-key'
      },
      {
        method: 'POST',
        path: '/lock/benchmark-resource'
      }
    ]
  });

  writeFileSync('benchmark-results.json', JSON.stringify(results, null, 2));
  console.log(results);
}

runBenchmark().catch(console.error);
