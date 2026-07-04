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

  try {
    const saPath = require('path').join(__dirname, '../../firebase-service-account.json');
    if (require('fs').existsSync(saPath)) {
      const serviceAccount = require(saPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: "https://fufaji-online-business-default-rtdb.firebaseio.com"
      });
      console.log('[firebaseAdmin] Initialized via local service account JSON');
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
