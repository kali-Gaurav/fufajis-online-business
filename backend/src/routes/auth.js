const express = require('express');
const router = express.Router();
const { admin } = require('../firestore');
const { verifyToken } = require('../auth');
const crypto = require('crypto');
const twilio = require('twilio');

// Redis for rate limiting (OTP + token refresh)
const redis = require('redis');
const redisClient = redis.createClient({
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379,
  password: process.env.REDIS_PASSWORD,
});
redisClient.on('error', (err) => console.error('[Redis] Error:', err));

const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
const TWILIO_PHONE = process.env.TWILIO_PHONE_NUMBER;

const OTP_RATE_LIMITS = {
  MAX_REQUESTS_PER_15_MIN: 3,
  MAX_REQUESTS_PER_HOUR: 10,
  LOCKOUT_DURATION_MIN: 15,
};

router.post('/onboard', verifyToken, async (req, res) => {
  const uid = req.user.uid;
  const phoneNumber = req.user.phone_number || req.user.phoneNumber;
  const email = req.user.email;

  try {
    const db = admin.firestore();
    let assignedRole = 'UserRole.customer';
    let assignedName = req.user.name || 'Fufaji User';
    let isAuthorized = false;

    // 1. Check phone number pre-authorization
    if (phoneNumber) {
      const docId = phoneNumber.replace('+', '');
      const authDoc = await db.collection('pre_authorized_users').doc(docId).get();
      if (authDoc.exists) {
        assignedRole = authDoc.data().role || assignedRole;
        assignedName = authDoc.data().name || assignedName;
        isAuthorized = true;
      }
    }

    // 2. Check email-based owners/employees pre-authorization
    if (!isAuthorized && email) {
      const ownerSnap = await db.collection('owners').where('email', '==', email).limit(1).get();
      if (!ownerSnap.empty) {
        assignedRole = 'UserRole.shopOwner';
        assignedName = ownerSnap.docs[0].data().name || assignedName;
        isAuthorized = true;
      } else {
        const empSnap = await db.collection('employees').where('email', '==', email).limit(1).get();
        if (!empSnap.empty) {
          assignedRole = 'UserRole.employee';
          assignedName = empSnap.docs[0].data().name || assignedName;
          isAuthorized = true;
        }
      }
    }

    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    
    const userUpdate = {
      id: uid,
      phoneNumber: phoneNumber || '',
      email: email || '',
      name: assignedName,
      role: assignedRole,
      createdAt: userDoc.exists && userDoc.data().createdAt ? userDoc.data().createdAt : admin.firestore.FieldValue.serverTimestamp(),
      lastLogin: admin.firestore.FieldValue.serverTimestamp(),
      isAuthorized: isAuthorized
    };

    await userRef.set(userUpdate, { merge: true });

    // Sync claims if owner or employee
    if (assignedRole === 'UserRole.shopOwner' || assignedRole === 'UserRole.admin') {
      await admin.auth().setCustomUserClaims(uid, { role: 'owner', employeeRole: null, isActive: true });
    } else if (assignedRole === 'UserRole.employee') {
      let empRole = 'packer';
      if (email) {
        const empSnap = await db.collection('employees').where('email', '==', email).limit(1).get();
        if (!empSnap.empty) {
          empRole = empSnap.docs[0].data().role || 'packer';
        }
      }
      await admin.auth().setCustomUserClaims(uid, { role: 'employee', employeeRole: empRole, isActive: true });
    }

    console.log(`Onboarded user: ${uid}. Role: ${assignedRole}`);
    return res.json({ success: true, user: userUpdate });
  } catch (e) {
    console.error('Error on user onboarding:', e);
    return res.status(500).json({ success: false, error: e.message });
  }
});

// ═══════════════════════════════════════════════════════════════════════
// FIX 1: TOKEN REFRESH WITH SIGNATURE VALIDATION
// ═══════════════════════════════════════════════════════════════════════

/**
 * POST /auth/refresh
 * Refresh ID token with signature validation + rate limiting
 * CRITICAL: Verify old token signature before issuing new one
 */
router.post('/refresh', async (req, res) => {
  const { refreshToken } = req.body;

  try {
    if (!refreshToken) {
      return res.status(400).json({ error: 'refresh_token_required' });
    }

    // ✅ VERIFY TOKEN SIGNATURE (Firebase validates automatically)
    const decoded = await admin.auth().verifyIdToken(refreshToken);
    const userId = decoded.uid;

    // ✅ RATE LIMIT: Max 5 refreshes per minute
    const rateLimitKey = `refresh_${userId}`;
    const refreshCount = parseInt(await redisClient.get(rateLimitKey) || '0') + 1;
    await redisClient.setex(rateLimitKey, 60, refreshCount.toString());

    if (refreshCount > 5) {
      console.warn(`[AUTH] Token refresh rate limit exceeded: ${userId} (${refreshCount} requests)`);
      return res.status(429).json({ error: 'rate_limited' });
    }

    // ✅ ISSUE NEW TOKEN
    const newToken = await admin.auth().createCustomToken(userId, {
      role: decoded.role || 'customer',
      isActive: true,
    });

    res.json({ success: true, token: newToken });
  } catch (err) {
    console.error('[AUTH] Token refresh failed:', err);
    res.status(401).json({ error: 'invalid_token' });
  }
});

// ═══════════════════════════════════════════════════════════════════════
// FIX 5: OTP RATE LIMITING
// ═══════════════════════════════════════════════════════════════════════

/**
 * POST /auth/send-otp
 * Send OTP with rate limiting (3 requests per 15 min, 10 per hour)
 */
router.post('/send-otp', async (req, res) => {
  const { phoneNumber } = req.body;

  try {
    // Validate phone format
    if (!phoneNumber || !/^\+?[1-9]\d{1,14}$/.test(phoneNumber)) {
      return res.status(400).json({ error: 'invalid_phone' });
    }

    // ✅ RATE LIMIT 1: 3 attempts per 15 minutes
    const key15min = `otp_rate_limit_15:${phoneNumber}`;
    const count15min = parseInt(await redisClient.get(key15min) || '0') + 1;
    await redisClient.setex(key15min, 900, count15min.toString()); // 15 min

    if (count15min > OTP_RATE_LIMITS.MAX_REQUESTS_PER_15_MIN) {
      console.warn(`[AUTH] OTP spam detected: ${phoneNumber} (${count15min} requests in 15min)`);
      return res.status(429).json({
        error: 'rate_limited',
        message: 'Too many OTP requests. Try again in 15 minutes.',
        retryAfter: 900,
      });
    }

    // ✅ RATE LIMIT 2: 10 attempts per hour (catch distributed attacks)
    const keyHour = `otp_rate_limit_hour:${phoneNumber}`;
    const countHour = parseInt(await redisClient.get(keyHour) || '0') + 1;
    await redisClient.setex(keyHour, 3600, countHour.toString()); // 1 hour

    if (countHour > OTP_RATE_LIMITS.MAX_REQUESTS_PER_HOUR) {
      console.error(`[AUTH] OTP abuse detected: ${phoneNumber} (${countHour} requests in 1 hour)`);
      return res.status(429).json({
        error: 'rate_limited_severe',
        message: 'Your account is temporarily locked. Contact support.',
        retryAfter: 3600,
      });
    }

    // ✅ GENERATE OTP (6 digits, 10 min expiry)
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpKey = `otp:${phoneNumber}`;

    await redisClient.setex(otpKey, 600, otp); // 10 min expiry

    // ✅ SEND VIA TWILIO
    try {
      await twilioClient.messages.create({
        body: `Your Fufaji OTP is: ${otp}. Valid for 10 minutes. Do not share.`,
        from: TWILIO_PHONE,
        to: phoneNumber,
      });
      console.log(`[AUTH] OTP sent to ${phoneNumber}`);
    } catch (twilioErr) {
      console.error('[AUTH] Twilio send failed:', twilioErr);
      // Fallback: log OTP for development (remove in production)
      if (process.env.NODE_ENV === 'development') {
        const db = admin.firestore();
        await db.collection('otp_logs').doc(phoneNumber).set({ otp, timestamp: new Date() }, { merge: true });
      }
      return res.status(500).json({ error: 'otp_send_failed' });
    }

    // ✅ RETURN SUCCESS (do NOT return OTP in response)
    res.json({
      success: true,
      message: 'OTP sent to your phone',
      expiresIn: 600, // seconds
    });
  } catch (err) {
    console.error('[AUTH] OTP send error:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

/**
 * POST /auth/verify-otp
 * Verify OTP code
 */
router.post('/verify-otp', async (req, res) => {
  const { phoneNumber, code } = req.body;

  try {
    if (!phoneNumber || !code || code.length !== 6) {
      return res.status(400).json({ error: 'invalid_input' });
    }

    const otpKey = `otp:${phoneNumber}`;
    const storedOtp = await redisClient.get(otpKey);

    if (!storedOtp) {
      return res.status(401).json({ error: 'otp_expired' });
    }

    if (storedOtp !== code) {
      return res.status(401).json({ error: 'invalid_otp' });
    }

    // ✅ OTP VALID: Delete it (one-time use)
    await redisClient.del(otpKey);

    // ✅ GET OR CREATE USER
    const db = admin.firestore();
    const userQuery = await db.collection('users').where('phoneNumber', '==', phoneNumber).limit(1).get();

    let userId;
    if (userQuery.empty) {
      // Create new user
      const newUserRef = db.collection('users').doc();
      userId = newUserRef.id;
      await newUserRef.set({
        phoneNumber,
        role: 'customer',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      userId = userQuery.docs[0].id;
    }

    // ✅ ISSUE FIREBASE TOKEN
    const token = await admin.auth().createCustomToken(userId, { role: 'customer' });

    res.json({ success: true, token, userId });
  } catch (err) {
    console.error('[AUTH] OTP verification error:', err);
    res.status(500).json({ error: 'verification_failed' });
  }
});

module.exports = router;
