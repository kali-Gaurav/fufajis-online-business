/**
 * genkitService.js - Firebase Genkit Initialization
 * Provides a unified AI instance for flows, tracing, and structured generation.
 */

const { genkit } = require('genkit');
const { googleAI, gemini15Flash } = require('@genkit-ai/googleai');
const secrets = require('../secrets');

let aiInstance = null;

/**
 * Get or initialize Genkit instance
 */
async function getAI() {
  if (aiInstance) return aiInstance;

  await secrets.loadSecrets();
  const apiKey = secrets.get('gemini/api_key');

  if (!apiKey) {
    throw new Error('Gemini API key not found in secrets.');
  }

  // Set the environment variable expected by @genkit-ai/googleai
  process.env.GOOGLE_GENAI_API_KEY = apiKey;

  aiInstance = genkit({
    plugins: [googleAI()],
    model: gemini15Flash, // Default model for the app
  });

  console.log('[Genkit] AI instance initialized with Gemini 1.5 Flash');
  return aiInstance;
}

module.exports = { getAI };
