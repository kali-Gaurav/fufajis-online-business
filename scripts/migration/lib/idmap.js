'use strict';

const { lookupId } = require('./pg');

/**
 * In-memory cache mapping Firestore doc ids -> Postgres uuids,
 * scoped per "entity kind" (users, products, orders, categories,
 * addresses). Falls back to a DB lookup (and caches the result)
 * if a reference is needed before that entity's own migrator has
 * run in this process (e.g. re-running with --only=orders after
 * users/products were migrated in a previous run).
 */
class IdMap {
  constructor() {
    this.maps = {
      users: new Map(), // firebase_uid -> users.id
      categories: new Map(), // firestore doc id -> categories.id
      addresses: new Map(), // firestore doc id -> addresses.id
      products: new Map(), // firestore_id -> products.id
      orders: new Map(), // firestore_id -> orders.id
      shops: new Map(), // firestore doc id (shops/{id}) -> shops.id
      branches: new Map(), // firestore doc id (shops/*/branches/{id}) -> branches.id
    };
    this.lookupConfig = {
      users: { table: 'users', column: 'firebase_uid' },
      categories: { table: 'categories', column: 'firestore_id' },
      addresses: { table: 'addresses', column: 'firestore_id' },
      products: { table: 'products', column: 'firestore_id' },
      orders: { table: 'orders', column: 'firestore_id' },
      shops: { table: 'shops', column: 'firestore_id' },
      branches: { table: 'branches', column: 'firestore_id' },
    };
  }

  set(kind, firestoreKey, pgId) {
    if (!firestoreKey || !pgId) return;
    this.maps[kind].set(firestoreKey, pgId);
  }

  /** Resolves a Postgres uuid for `firestoreKey`, querying the DB on cache miss. */
  async resolve(client, kind, firestoreKey) {
    if (!firestoreKey) return null;
    const cached = this.maps[kind].get(firestoreKey);
    if (cached) return cached;

    const cfg = this.lookupConfig[kind];
    if (!cfg) throw new Error(`IdMap: unknown kind "${kind}"`);

    const id = await lookupId(client, cfg.table, cfg.column, firestoreKey);
    if (id) this.maps[kind].set(firestoreKey, id);
    return id;
  }
}

module.exports = { IdMap };
