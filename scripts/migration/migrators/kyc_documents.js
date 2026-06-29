'use strict';

const { pick, ts } = require('../lib/transform');

const VALID_DOC_TYPES = new Set(['aadhaar', 'pan', 'gst', 'license', 'shop_proof', 'bank_proof', 'other']);
const VALID_STATUS = new Set(['pending', 'verified', 'rejected']);

/** Firestore `kyc_documents/{id}` (or `users/{uid}/kyc_documents/{id}`) -> Postgres `kyc_documents`. */
module.exports = {
  name: 'kyc_documents',
  table: 'kyc_documents',
  collection: 'kyc_documents',
  collectionGroup: true,
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    const userFsId = pick(d, ['userId', 'user_id'])
      || (doc.ref.parent.path.startsWith('users/') ? doc.ref.parent.parent.id : undefined);
    const userId = await idmap.resolve(client, 'users', String(userFsId || ''));

    if (!userId) {
      return null; // user_id is NOT NULL — skip unresolvable rows
    }

    const reviewedByFsId = pick(d, ['reviewedBy', 'reviewed_by']);
    const reviewedBy = reviewedByFsId ? await idmap.resolve(client, 'users', String(reviewedByFsId)) : null;

    let docType = String(pick(d, ['docType', 'doc_type'], 'other')).toLowerCase();
    if (!VALID_DOC_TYPES.has(docType)) docType = 'other';

    let status = String(pick(d, ['status'], 'pending')).toLowerCase();
    if (!VALID_STATUS.has(status)) status = 'pending';

    return {
      firestore_id: doc.id,
      user_id: userId,
      doc_type: docType,
      doc_number: pick(d, ['docNumber', 'doc_number']) || null,
      file_url: pick(d, ['fileUrl', 'file_url']) || null,
      status,
      rejection_reason: pick(d, ['rejectionReason', 'rejection_reason']) || null,
      reviewed_by: reviewedBy,
      reviewed_at: ts(pick(d, ['reviewedAt', 'reviewed_at'])),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || undefined,
    };
  },
};
