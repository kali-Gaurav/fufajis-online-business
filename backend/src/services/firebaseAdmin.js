// centralized Firebase Admin SDK wiring for Fufaji Store backend.
// Handles initialization via Service Account (Railway) or default credentials.

const admin = require('firebase-admin');
const secrets = require('../secrets');

let initialized = false;

/**
 * Initializes the Firebase Admin SDK.
 * Supports Railway (via FIREBASE_SERVICE_ACCOUNT env var) and AWS SSM.
 */
async function init() {
  if (initialized) return admin;

  await secrets.loadSecrets();

  const saSecret = secrets.get('FIREBASE_SERVICE_ACCOUNT');

  try {
    if (saSecret) {
      // Initialize with Service Account JSON
      const serviceAccount = typeof saSecret === 'string' ? JSON.parse(saSecret) : saSecret;
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
      console.log('[firebaseAdmin] Initialized via Service Account');
    } else {
      // Fallback to default credentials (works in Google Cloud or if GOOGLE_APPLICATION_CREDENTIALS is set)
      admin.initializeApp();
      console.log('[firebaseAdmin] Initialized via Default Credentials');
    }

    initialized = true;
  } catch (error) {
    console.error('[firebaseAdmin] Initialization failed:', error.message);
    throw error;
  }

  return admin;
}

/**
 * Convenience handles for Firestore and Auth.
 */
const db = () => {
  if (!initialized) throw new Error('Firebase Admin not initialized. Call init() first.');
  return admin.firestore();
};

const auth = () => {
  if (!initialized) throw new Error('Firebase Admin not initialized. Call init() first.');
  return admin.auth();
};

module.exports = {
  init,
  admin,
  db,
  auth
};
