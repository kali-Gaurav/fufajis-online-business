// Lambda entry point. Wraps the Express app with serverless-http and ensures
// secrets + firebase-admin are initialized exactly once per container (cold
// start), before any request is handled.

const serverless = require('serverless-http');
const app = require('./app');
const secrets = require('./secrets');
const { initFirebase } = require('./firestore');
const jobs = require('./jobs');

let warmPromise = null;
function warm() {
  if (!warmPromise) {
    warmPromise = (async () => {
      await secrets.loadSecrets();
      await initFirebase();
    })();
  }
  return warmPromise;
}

const handler = serverless(app);

module.exports.handler = async (event, context) => {
  context.callbackWaitsForEmptyEventLoop = false;
  await warm();

  // If it's a scheduled EventBridge event or direct job invocation
  if (event.job || event['detail-type'] === 'Scheduled Event' || event.source === 'aws.events') {
    return jobs.runJob(event);
  }

  return handler(event, context);
};
