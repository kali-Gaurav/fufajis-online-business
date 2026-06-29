'use strict';

// Order matters: entities referenced by foreign keys must be migrated
// before the entities that reference them, so the IdMap has values to
// resolve (the DB-fallback lookup in IdMap also covers --only reruns).
module.exports = [
  require('./shops'),
  require('./branches'),
  require('./users'),
  require('./categories'),
  require('./addresses'),
  require('./products'),
  require('./orders'),
  require('./reviews'),
  require('./wallet_transactions'),
  require('./support_tickets'),
  require('./coupons'),
  require('./kyc_documents'),
  require('./notifications'),
  require('./inventory_logs'),
  require('./delivery_tracking'),
];
