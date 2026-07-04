require('dotenv').config({ path: '../.env' });
const { Redis } = require('@upstash/redis');

async function checkRedis() {
    try {
        const redisClient = new Redis({
          url: process.env.UPSTASH_REDIS_REST_URL,
          token: process.env.UPSTASH_REDIS_REST_TOKEN,
        });
        
        await redisClient.set('test_key', 'test_val');
        const val = await redisClient.get('test_key');
        console.log("Redis OK, val:", val);
    } catch (e) {
        console.error("Redis Error:", e.message);
    }
}
checkRedis();
