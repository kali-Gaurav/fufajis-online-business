'use strict';

const { pick, num, bool, ts, strArray, jsonb } = require('../lib/transform');

/** Firestore `products/{id}` -> Postgres `products`. */
module.exports = {
  name: 'products',
  table: 'products',
  collection: 'products',
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    const vendorFsId = pick(d, ['vendorId', 'vendor_id', 'ownerId', 'shopOwnerId']);
    const categoryFsId = pick(d, ['categoryId', 'category_id']);
    const shopFsId = pick(d, ['shopId', 'shop_id']);

    const vendorId = vendorFsId ? await idmap.resolve(client, 'users', String(vendorFsId)) : null;
    const categoryId = categoryFsId ? await idmap.resolve(client, 'categories', String(categoryFsId)) : null;
    const shopId = shopFsId ? await idmap.resolve(client, 'shops', String(shopFsId)) : null;

    return {
      firestore_id: doc.id,
      vendor_id: vendorId,
      category_id: categoryId,
      shop_id: shopId,
      name: pick(d, ['name', 'title'], ''),
      name_hi: pick(d, ['nameHi', 'name_hi']) || null,
      description: pick(d, ['description', 'desc']) || null,
      sku: pick(d, ['sku']) || null,
      barcode: pick(d, ['barcode']) || null,
      unit: pick(d, ['unit']) || null,
      price: num(pick(d, ['price', 'sellingPrice'], 0)),
      mrp: num(pick(d, ['mrp', 'maxRetailPrice'], 0)),
      cost_price: pick(d, ['costPrice', 'cost_price']) != null ? num(pick(d, ['costPrice', 'cost_price'])) : null,
      stock_quantity: Math.trunc(num(pick(d, ['stockQuantity', 'stock', 'stock_quantity']), 0)),
      low_stock_threshold: Math.trunc(num(pick(d, ['lowStockThreshold', 'low_stock_threshold']), 5)),
      image_urls: strArray(pick(d, ['imageUrls', 'images', 'image_urls'])) || [],
      tags: strArray(pick(d, ['tags'])) || [],
      is_active: bool(pick(d, ['isActive', 'is_active']), true),
      is_featured: bool(pick(d, ['isFeatured', 'is_featured']), false),
      rating: pick(d, ['rating']) != null ? num(pick(d, ['rating'])) : null,
      rating_count: Math.trunc(num(pick(d, ['ratingCount', 'rating_count']), 0)),
      metadata: jsonb(pick(d, ['metadata']), {}),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || undefined,
    };
  },

  async afterUpsert(client, doc, row, pgId, idmap) {
    idmap.set('products', doc.id, pgId);
  },
};
