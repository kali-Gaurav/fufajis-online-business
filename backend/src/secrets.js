// Modernized Secret Management Service.
// Supports both Railway (process.env) and legacy AWS SSM.
// Prefer process.env for local dev and Railway.

const { SSMClient, GetParametersByPathCommand } = require('@aws-sdk/client-ssm');

const REGION = process.env.AWS_REGION || 'ap-south-1';
const PREFIX = process.env.SSM_PREFIX || '/fufaji/';

let cache = null;

/**
 * Loads secrets into memory.
 * First checks for AWS SSM, falls back to process.env.
 */
async function loadSecrets() {
  if (cache) return cache;

  const out = {};

  // Try loading from SSM if AWS environment is detected
  if (process.env.AWS_LAMBDA_FUNCTION_NAME || process.env.USE_SSM === 'true') {
    try {
      const ssm = new SSMClient({ region: REGION });
      let nextToken;
      do {
        const res = await ssm.send(
          new GetParametersByPathCommand({
            Path: PREFIX,
            Recursive: true,
            WithDecryption: true,
            NextToken: nextToken,
          })
        );
        for (const p of res.Parameters || []) {
          // Normalize key name: strip prefix and replace slashes with underscores
          const key = p.Name.substring(PREFIX.length).replace(/\//g, '_').toUpperCase();
          out[key] = p.Value;
        }
        nextToken = res.NextToken;
      } while (nextToken);
    } catch (e) {
      console.warn('[secrets] AWS SSM load failed, falling back to process.env:', e.message);
    }
  }

  // Merge with process.env (Railway standard)
  // This allows overriding SSM params with ENV vars
  Object.keys(process.env).forEach(key => {
    out[key] = process.env[key];
  });

  cache = out;
  return out;
}

/**
 * Gets a secret value by key.
 * @param {string} key - The secret key (e.g., 'RAZORPAY_KEY_ID' or 'firebase/service_account')
 */
function get(key) {
  if (!cache) {
    // Sync fallback if loadSecrets wasn't awaited (not ideal for SSM but works for process.env)
    return process.env[key.replace(/\//g, '_').toUpperCase()] || process.env[key];
  }

  // Try exact match first
  if (cache[key]) return cache[key];

  // Try normalized version (e.g. firebase/service_account -> FIREBASE_SERVICE_ACCOUNT)
  const normalizedKey = key.replace(/\//g, '_').toUpperCase();
  return cache[normalizedKey];
}

module.exports = { loadSecrets, get };
