/**
 * MFA Routes - Server-side TOTP + PIN validation
 * CRITICAL: Never expose secrets client-side
 */

const express = require('express');
const router = express.Router();
const { admin } = require('../firestore');
const { verifyToken } = require('../auth');
const crypto = require('crypto');
const speakeasy = require('speakeasy');

const ENCRYPTION_KEY = process.env.MFA_ENCRYPTION_KEY || crypto.randomBytes(32);

// ═══════════════════════════════════════════════════════════════════════
// TOTP VERIFICATION (Server-Side) — PIN LOCKOUT (Server-Side)
// ═══════════════════════════════════════════════════════════════════════

/**
 * POST /mfa/verify-totp
 * Verify TOTP code server-side (secret never exposed)
 */
router.post('/verify-totp', verifyToken, async (req, res) => {
  const { code } = req.body;
  const userId = req.user.uid;

  try {
    if (!code || code.length !== 6) {
      return res.status(400).json({ success: false, message: 'Invalid code format' });
    }

    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const userData = userDoc.data();
    const encryptedSecret = userData.mfaTotpSecret;

    if (!encryptedSecret) {
      return res.status(400).json({ success: false, message: 'TOTP not configured' });
    }

    // Decrypt secret (server-side only)
    const decrypted = decryptSecret(encryptedSecret);

    // Verify TOTP (allow 30-sec window before/after)
    const isValid = speakeasy.totp.verify({
      secret: decrypted,
      encoding: 'base32',
      token: code,
      window: 1,
    });

    if (isValid) {
      return res.json({ success: true, message: 'TOTP verified' });
    }

    // Check backup codes
    const backupCodes = userData.mfaBackupCodes || [];
    const hashedCode = hashBackupCode(code);

    if (backupCodes.includes(hashedCode)) {
      // Backup code is valid; remove it (one-time use)
      await db.collection('users').doc(userId).update({
        mfaBackupCodes: admin.firestore.FieldValue.arrayRemove(hashedCode),
      });
      return res.json({ success: true, message: 'Backup code used' });
    }

    return res.status(401).json({ success: false, message: 'Invalid code' });
  } catch (err) {
    console.error('[MFA] TOTP verification error:', err);
    res.status(500).json({ success: false, message: 'Verification failed' });
  }
});

/**
 * POST /mfa/verify-pin
 * Verify PIN server-side with rate-limiting + lockout enforcement
 */
router.post('/verify-pin', verifyToken, async (req, res) => {
  const { pin } = req.body;
  const userId = req.user.uid;

  try {
    const db = admin.firestore();
    const now = new Date();

    // Check if user is locked out (server-side state)
    const lockoutDoc = await db.collection('pin_lockouts').doc(userId).get();
    let lockoutData = null;
    if (lockoutDoc.exists) {
      lockoutData = lockoutDoc.data();
      if (new Date(lockoutData.lockedUntil) > now) {
        const remainingMs = new Date(lockoutData.lockedUntil) - now;
        const remainingMin = Math.ceil(remainingMs / 60000);
        return res.status(429).json({
          success: false,
          message: `Account locked. Try again in ${remainingMin} minutes`,
          remainingMinutes: remainingMin,
        });
      }
    }

    // Get user's PIN hash
    const userDoc = await db.collection('owners').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const userData = userDoc.data();
    const storedPinHash = userData.pinHash;

    if (!storedPinHash) {
      return res.status(400).json({ success: false, message: 'PIN not configured' });
    }

    // Verify PIN (PBKDF2)
    const isValid = verifyPinHash(pin, storedPinHash);

    if (isValid) {
      // Clear failed attempts on success
      await db.collection('pin_lockouts').doc(userId).delete();
      return res.json({ success: true, message: 'PIN verified' });
    }

    // Increment failed attempts
    const failedAttempts = (lockoutData?.failedAttempts || 0) + 1;

    if (failedAttempts >= 5) {
      // Lock account for 30 minutes
      const lockedUntil = new Date(now.getTime() + 30 * 60 * 1000);
      await db.collection('pin_lockouts').doc(userId).set({
        userId,
        failedAttempts,
        lockedUntil: lockedUntil.toISOString(),
        lastFailedAt: now.toISOString(),
      });

      return res.status(429).json({
        success: false,
        message: 'Too many failed attempts. Account locked for 30 minutes.',
        remainingMinutes: 30,
      });
    }

    // Update failed attempts
    await db.collection('pin_lockouts').doc(userId).set({
      userId,
      failedAttempts,
      lastFailedAt: now.toISOString(),
    });

    res.status(401).json({
      success: false,
      message: `Invalid PIN. ${5 - failedAttempts} attempts remaining.`,
      attemptsRemaining: 5 - failedAttempts,
    });
  } catch (err) {
    console.error('[MFA] PIN verification error:', err);
    res.status(500).json({ success: false, message: 'Verification failed' });
  }
});

/**
 * POST /mfa/reset-pin
 * Server-side PIN reset with email verification
 */
router.post('/mfa/reset-pin', verifyToken, async (req, res) => {
  const { newPin, email } = req.body;
  const userId = req.user.uid;

  try {
    const db = admin.firestore();

    // Verify email matches user
    const userDoc = await db.collection('owners').doc(userId).get();
    if (!userDoc.exists || userDoc.data().email !== email) {
      return res.status(403).json({ success: false, message: 'Email mismatch' });
    }

    // Hash new PIN
    const newPinHash = hashPin(newPin);

    // Update PIN + clear lockout
    await Promise.all([
      db.collection('owners').doc(userId).update({ pinHash: newPinHash }),
      db.collection('pin_lockouts').doc(userId).delete(),
    ]);

    res.json({ success: true, message: 'PIN reset successfully' });
  } catch (err) {
    console.error('[MFA] PIN reset error:', err);
    res.status(500).json({ success: false, message: 'Reset failed' });
  }
});

/**
 * GET /mfa/session-status
 * Check if session is still valid (token refresh check)
 */
router.get('/mfa/session-status', verifyToken, async (req, res) => {
  const userId = req.user.uid;
  const db = admin.firestore();

  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(401).json({ success: false, message: 'Session invalid' });
    }

    res.json({ success: true, message: 'Session valid' });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Check failed' });
  }
});

// ═══════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════

function encryptSecret(secret) {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-cbc', ENCRYPTION_KEY, iv);
  let encrypted = cipher.update(secret, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return iv.toString('hex') + ':' + encrypted;
}

function decryptSecret(encrypted) {
  const [iv, encryptedSecret] = encrypted.split(':');
  const decipher = crypto.createDecipheriv('aes-256-cbc', ENCRYPTION_KEY, Buffer.from(iv, 'hex'));
  let decrypted = decipher.update(encryptedSecret, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

function hashPin(pin) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.pbkdf2Sync(pin, salt, 10000, 32, 'sha256').toString('hex');
  return `pbkdf2$10000$${salt}$${hash}`;
}

function verifyPinHash(pin, storedHash) {
  const [, iterations, salt, hash] = storedHash.split('$');
  const computed = crypto.pbkdf2Sync(pin, salt, parseInt(iterations), 32, 'sha256').toString('hex');
  return computed === hash;
}

function hashBackupCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

module.exports = router;
