const functions = require('firebase-functions');
const admin = require('firebase-admin');
const bcrypt = require('bcrypt');

const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_DURATION_MS = 15 * 60 * 1000; // 15 minutes

exports.verifyStaffCredentials = functions.https.onCall(async (data, context) => {
  const { loginId, pin, role } = data;

  if (!loginId || !pin || !role) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: loginId, pin, role');
  }

  const db = admin.firestore();
  let credentialDoc;
  let credentialData;
  let credentialRef;

  try {
    const credSnapshot = await db.collection('staff_credentials')
      .where('loginId', '==', loginId)
      .limit(1)
      .get();

    if (credSnapshot.empty) {
      // To prevent user enumeration, log and return generic error
      await logAuthAttempt(db, loginId, 'failure', 'User not found');
      throw new functions.https.HttpsError('unauthenticated', 'Invalid login credentials');
    }

    credentialDoc = credSnapshot.docs[0];
    credentialRef = credentialDoc.ref;
    credentialData = credentialDoc.data();

  } catch (error) {
    console.error('Error fetching staff credentials', error);
    throw new functions.https.HttpsError('internal', 'Internal error occurred during authentication');
  }

  // 1. Check for lockout
  if (credentialData.lockedUntil) {
    const lockedUntilDate = credentialData.lockedUntil.toDate();
    if (lockedUntilDate > new Date()) {
      await logAuthAttempt(db, loginId, 'failure', 'Account locked out');
      throw new functions.https.HttpsError('unauthenticated', 'Account temporarily locked due to too many failed attempts. Try again later.');
    }
  }

  // 2. Verify PIN
  const isValid = await bcrypt.compare(pin, credentialData.pinHash);

  if (!isValid) {
    // 3a. Handle Failure
    const newFailedAttempts = (credentialData.failedAttempts || 0) + 1;
    let lockedUntil = null;

    if (newFailedAttempts >= MAX_FAILED_ATTEMPTS) {
      lockedUntil = admin.firestore.Timestamp.fromMillis(Date.now() + LOCKOUT_DURATION_MS);
      await logAuthAttempt(db, loginId, 'lockout', 'Max failed attempts reached');
    } else {
      await logAuthAttempt(db, loginId, 'failure', 'Invalid PIN');
    }

    await credentialRef.update({
      failedAttempts: newFailedAttempts,
      lockedUntil: lockedUntil
    });

    throw new functions.https.HttpsError('unauthenticated', 'Invalid login credentials');
  }

  // 3b. Handle Success
  try {
    // Fetch user details to verify role and status
    const userSnapshot = await db.collection('users').doc(credentialData.userId).get();
    if (!userSnapshot.exists) {
      await logAuthAttempt(db, loginId, 'failure', 'User profile not found');
      throw new functions.https.HttpsError('unauthenticated', 'User profile not found');
    }

    const userData = userSnapshot.data();
    
    // Optional: Verify role and active status
    if (userData.role !== role) {
       await logAuthAttempt(db, loginId, 'failure', 'Role mismatch');
       throw new functions.https.HttpsError('permission-denied', 'Role mismatch');
    }

    if (userData.isActive === false) {
      await logAuthAttempt(db, loginId, 'failure', 'Account disabled');
      throw new functions.https.HttpsError('permission-denied', 'Account is disabled');
    }

    // Update lastLoginAt on users collection
    await userSnapshot.ref.update({
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Reset failed attempts
    await credentialRef.update({
      failedAttempts: 0,
      lockedUntil: null
    });

    // Create Custom Token
    // We add the 'role' claim directly in the custom token for convenience,
    // but the Firebase auth flow normally relies on custom claims set on the user.
    // It's a good practice to ensure custom claims are synced.
    const customClaims = {
      role: role,
      serviceAuth: false,
    };
    
    const customToken = await admin.auth().createCustomToken(credentialData.userId, customClaims);

    await logAuthAttempt(db, loginId, 'success', 'Login successful');

    return {
      success: true,
      token: customToken,
      user: {
        uid: credentialData.userId,
        role: role
      }
    };
  } catch (error) {
    console.error('Error finalizing auth', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', 'Internal error occurred during authentication');
  }
});

async function logAuthAttempt(db, loginId, result, reason) {
  try {
    await db.collection('auth_logs').add({
      loginId: loginId,
      result: result,
      reason: reason,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (err) {
    console.error('Failed to write auth log:', err);
  }
}
