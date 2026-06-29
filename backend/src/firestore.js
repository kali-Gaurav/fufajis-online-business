// Legacy wrapper for the new firebaseAdmin service.
// Re-exports handles for backward compatibility during transition.

const firebaseAdmin = require('./services/firebaseAdmin');

module.exports = {
  initFirebase: firebaseAdmin.init,
  admin: firebaseAdmin.admin,
  db: firebaseAdmin.db
};
