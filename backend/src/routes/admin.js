// Ported from functions/index.js:
//   setRole         -> POST /admin/roles/set     (admin only)
//   syncUserClaims  -> POST /admin/claims/sync   (any signed-in user)
//
// Contracts preserved:
//   setRole:        body { targetUserId, newRole } -> { success, message }
//   syncUserClaims: no body -> { success, role, employeeRole, isActive }

const express = require('express');
const router = express.Router();
const { admin } = require('../firestore');
const { verifyToken, requireRole } = require('../auth');
const supabaseService = require('../../config/supabase');

// ── setRole (admin only; inline check preserves the audit-log requester name) ──
router.post('/roles/set', verifyToken, async (req, res) => {
  const { targetUserId, newRole } = req.body || {};
  if (!targetUserId || !newRole) {
    return res.status(400).json({ success: false, error: 'Missing targetUserId or newRole.' });
  }
  try {
    const db = admin.firestore();
    const requesterDoc = await db.collection('users').doc(req.user.uid).get();
    if (!requesterDoc.exists || requesterDoc.data().role !== 'UserRole.admin') {
      return res.status(403).json({ success: false, error: 'Only admins can change user roles.' });
    }

    await db.collection('users').doc(targetUserId).update({
      role: newRole,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await db.collection('audit_logs').add({
      userId: req.user.uid,
      userName: requesterDoc.data().name || 'Admin',
      action: 'AuditAction.roleChange',
      description: `Changed role of user ${targetUserId} to ${newRole}`,
      metadata: { targetUserId, newRole },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Dual-write role change to Supabase
    try {
      const cleanRole = newRole.replace('UserRole.', '');
      await supabaseService.query('users', 'update', {
        payload: { role: cleanRole, updated_at: new Date().toISOString() },
        filters: { firebase_uid: targetUserId }
      });
      console.log(`[Supabase] Role dual-write successful for ${targetUserId}`);
    } catch (sbErr) {
      console.error(`[Supabase] Role dual-write failed for ${targetUserId}:`, sbErr.message);
    }

    return res.json({ success: true, message: `Role updated to ${newRole} for user ${targetUserId}` });
  } catch (e) {
    console.error('Error setting role:', e);
    return res.status(500).json({ success: false, error: e.message });
  }
});

// ── syncUserClaims (assigns owner/employee/none custom claims) ──
router.post('/claims/sync', verifyToken, async (req, res) => {
  const uid = req.user.uid;
  const email = req.user.email;
  if (!email) {
    return res.status(400).json({ success: false, error: 'Authenticated user has no email.' });
  }
  try {
    const db = admin.firestore();

    // 1. Owner?
    const ownerSnap = await db.collection('owners').where('email', '==', email).limit(1).get();
    if (!ownerSnap.empty) {
      const claims = { role: 'owner', employeeRole: null, isActive: true };
      await admin.auth().setCustomUserClaims(uid, claims);
      console.log(`[syncUserClaims] OWNER claims -> ${email} (${uid})`);
      return res.json({ success: true, ...claims });
    }

    // 2. Employee?
    const empSnap = await db.collection('employees').where('email', '==', email).limit(1).get();
    if (!empSnap.empty) {
      const empData = empSnap.docs[0].data();
      const claims = {
        role: 'employee',
        employeeRole: empData.role || 'packer',
        isActive: empData.isActive !== false,
      };
      if (!empData.uid || empData.uid !== uid) {
        await empSnap.docs[0].ref.update({
          uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await admin.auth().setCustomUserClaims(uid, claims);
      console.log(`[syncUserClaims] EMPLOYEE claims -> ${email} (${uid})`);
      return res.json({ success: true, ...claims });
    }

    // 3. No privileges.
    const claims = { role: null, employeeRole: null, isActive: false };
    await admin.auth().setCustomUserClaims(uid, claims);
    console.log(`[syncUserClaims] cleared claims -> ${email} (${uid})`);
    return res.json({ success: true, ...claims });
  } catch (e) {
    console.error('[syncUserClaims] Error:', e);
    return res.status(500).json({ success: false, error: 'Internal error synchronizing custom claims: ' + e.message });
  }
});

// ── syncUserClaimsForAdmin (admin only; sync claims for a specific user) ──
router.post('/claims/sync-user', verifyToken, requireRole('UserRole.admin'), async (req, res) => {
  const { email, targetUserId } = req.body || {};

  let targetUid = targetUserId;
  let targetEmail = email;

  if (!targetUid && !targetEmail) {
    return res.status(400).json({ success: false, error: 'Missing email or targetUserId.' });
  }

  try {
    const db = admin.firestore();

    // Resolve email and uid if only one is provided
    if (!targetUid && targetEmail) {
      try {
        const userRecord = await admin.auth().getUserByEmail(targetEmail);
        targetUid = userRecord.uid;
      } catch (e) {
        return res.status(404).json({ success: false, error: 'User not found in Firebase Auth.' });
      }
    } else if (targetUid && !targetEmail) {
      try {
        const userRecord = await admin.auth().getUser(targetUid);
        targetEmail = userRecord.email;
      } catch (e) {
        return res.status(404).json({ success: false, error: 'User not found in Firebase Auth.' });
      }
    }

    if (!targetEmail) {
      return res.status(400).json({ success: false, error: 'Target user has no email address.' });
    }

    // 1. Owner?
    const ownerSnap = await db.collection('owners').where('email', '==', targetEmail).limit(1).get();
    if (!ownerSnap.empty) {
      const claims = { role: 'owner', employeeRole: null, isActive: true };
      await admin.auth().setCustomUserClaims(targetUid, claims);
      return res.json({ success: true, uid: targetUid, email: targetEmail, ...claims });
    }

    // 2. Employee?
    const empSnap = await db.collection('employees').where('email', '==', targetEmail).limit(1).get();
    if (!empSnap.empty) {
      const empData = empSnap.docs[0].data();
      const claims = {
        role: 'employee',
        employeeRole: empData.role || 'packer',
        isActive: empData.isActive !== false
      };
      if (!empData.uid || empData.uid !== targetUid) {
        await empSnap.docs[0].ref.update({
          uid: targetUid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
      await admin.auth().setCustomUserClaims(targetUid, claims);
      return res.json({ success: true, uid: targetUid, email: targetEmail, ...claims });
    }

    // 3. Customer / default
    const claims = { role: null, employeeRole: null, isActive: false };
    await admin.auth().setCustomUserClaims(targetUid, claims);
    return res.json({ success: true, uid: targetUid, email: targetEmail, ...claims });

  } catch (e) {
    console.error('[sync-user] Error syncing claims:', e);
    return res.status(500).json({ success: false, error: e.message });
  }
});

module.exports = router;
