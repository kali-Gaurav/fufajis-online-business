/**
 * FUFAJI STORE — Firebase Configuration & Service
 * Date: 2026-07-02
 * Status: PRODUCTION-READY
 *
 * SECURITY FIXES:
 * ✅ NO hardcoded API keys
 * ✅ Environment variables via .env
 * ✅ Firestore persistence enabled
 * ✅ Error handling & logging
 */

import { initializeApp } from 'firebase/app';
import {
  getAuth,
  setPersistence,
  inMemoryPersistence,
  GoogleAuthProvider,
  signInWithCredential,
  onAuthStateChanged,
  signOut,
} from 'firebase/auth';
import {
  getFirestore,
  doc,
  setDoc,
  getDoc,
  collection,
  query,
  where,
  getDocs,
  addDoc,
  updateDoc,
  serverTimestamp,
  enableIndexedDbPersistence,
} from 'firebase/firestore';
import { getStorage } from 'firebase/storage';

// ===== FIREBASE CONFIG (From Environment Variables) =====
const firebaseConfig = {
  apiKey: process.env.EXPO_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.EXPO_PUBLIC_FIREBASE_APP_ID,
};

// Validate config
if (!firebaseConfig.projectId) {
  throw new Error('❌ Firebase config missing! Check .env file.');
}

// ===== INITIALIZE FIREBASE =====
const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

// ===== PERSISTENCE SETUP =====
// Use in-memory persistence for Expo (no AsyncStorage yet)
setPersistence(auth, inMemoryPersistence).catch(err => {
  console.warn('⚠️ Auth persistence warning:', err.message);
});

// Enable offline persistence for Firestore (mobile support)
enableIndexedDbPersistence(db).catch(err => {
  if (err.code === 'failed-precondition') {
    console.warn('⚠️ Multiple tabs open, persistence disabled');
  } else if (err.code === 'unimplemented') {
    console.warn('⚠️ Browser does not support persistence');
  }
});

// ===== GOOGLE AUTH PROVIDER =====
export const googleProvider = new GoogleAuthProvider();
googleProvider.addScope('profile');
googleProvider.addScope('email');

// ===== USER SERVICE =====
/**
 * FIX #2: Create user document on first login
 * This prevents "permission denied" errors
 */
export const createUserIfMissing = async (user) => {
  if (!user) return null;

  try {
    const userRef = doc(db, 'users', user.uid);
    const userSnap = await getDoc(userRef);

    // User already exists
    if (userSnap.exists()) {
      console.log('✅ User exists:', user.uid);
      return userSnap.data();
    }

    // First login — create user document
    const newUserData = {
      uid: user.uid,
      email: user.email || '',
      displayName: user.displayName || 'Customer',
      photoURL: user.photoURL || null,
      phone: null, // To be filled later
      createdAt: new Date().toISOString(),
      lastLoginAt: new Date().toISOString(),
      country: 'IN',
      language: 'hi', // Default: Hindi
      isAdmin: false,
      isEmailVerified: user.emailVerified || false,
    };

    await setDoc(userRef, newUserData);
    console.log('✅ New user created:', user.uid);
    return newUserData;
  } catch (error) {
    console.error('❌ Error creating user:', error);
    throw new Error(`User creation failed: ${error.message}`);
  }
};

// ===== AUTH STATE LISTENER =====
/**
 * Monitor auth state changes
 * Call this once on app startup
 */
export const setupAuthListener = (onAuthChange) => {
  return onAuthStateChanged(auth, async (user) => {
    if (user) {
      console.log('✅ User logged in:', user.uid);

      // Create/fetch user document
      try {
        await createUserIfMissing(user);
        onAuthChange(user);
      } catch (error) {
        console.error('❌ Auth listener error:', error);
        onAuthChange(null);
      }
    } else {
      console.log('❌ User logged out');
      onAuthChange(null);
    }
  });
};

// ===== SIGN OUT =====
export const logout = async () => {
  try {
    await signOut(auth);
    console.log('✅ Logged out');
  } catch (error) {
    console.error('❌ Logout error:', error);
    throw error;
  }
};

// ===== GET USER DATA =====
export const getUserData = async (uid) => {
  try {
    const userRef = doc(db, 'users', uid);
    const userSnap = await getDoc(userRef);
    return userSnap.exists() ? userSnap.data() : null;
  } catch (error) {
    console.error('❌ Error fetching user:', error);
    return null;
  }
};

// ===== UPDATE USER PROFILE =====
export const updateUserProfile = async (uid, updates) => {
  try {
    const userRef = doc(db, 'users', uid);
    const safeUpdates = {
      ...updates,
      updatedAt: new Date().toISOString(),
    };

    // Prevent privilege escalation
    if ('isAdmin' in safeUpdates) {
      delete safeUpdates.isAdmin;
      console.warn('⚠️ isAdmin cannot be updated by user');
    }

    await setDoc(userRef, safeUpdates, { merge: true });
    console.log('✅ User profile updated');
    return true;
  } catch (error) {
    console.error('❌ Error updating profile:', error);
    throw error;
  }
};

// ===== WALLET OPERATIONS =====
export const getWalletBalance = async (uid) => {
  try {
    const walletRef = doc(db, 'wallet', uid);
    const walletSnap = await getDoc(walletRef);
    return walletSnap.exists() ? walletSnap.data().balance || 0 : 0;
  } catch (error) {
    console.error('❌ Error fetching wallet:', error);
    return 0;
  }
};

export const addWalletTransaction = async (uid, amount, type, description) => {
  try {
    const transRef = collection(db, 'wallet', uid, 'transactions');
    const transaction = {
      amount,
      type, // 'credit' or 'debit'
      description,
      timestamp: serverTimestamp(),
      balanceAfter: await getWalletBalance(uid) + (type === 'credit' ? amount : -amount),
    };
    await addDoc(transRef, transaction);
    console.log('✅ Wallet transaction added');
    return transaction;
  } catch (error) {
    console.error('❌ Error adding wallet transaction:', error);
    throw error;
  }
};

// ===== NOTIFICATIONS =====
export const sendNotification = async (uid, title, message, type = 'info') => {
  try {
    const notifRef = collection(db, 'notifications', uid, 'notificationId');
    const notification = {
      title,
      message,
      type, // 'info', 'warning', 'success', 'error'
      read: false,
      timestamp: serverTimestamp(),
    };
    await addDoc(notifRef, notification);
    console.log('✅ Notification sent');
    return notification;
  } catch (error) {
    console.error('❌ Error sending notification:', error);
    throw error;
  }
};

export const getNotifications = async (uid, limit = 10) => {
  try {
    const notifRef = collection(db, 'notifications', uid, 'notificationId');
    const q = query(notifRef);
    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })).slice(0, limit);
  } catch (error) {
    console.error('❌ Error fetching notifications:', error);
    return [];
  }
};

// ===== DELIVERY TRACKING =====
export const getDeliveryStatus = async (deliveryId) => {
  try {
    const deliveryRef = doc(db, 'deliveries', deliveryId);
    const deliverySnap = await getDoc(deliveryRef);
    return deliverySnap.exists() ? deliverySnap.data() : null;
  } catch (error) {
    console.error('❌ Error fetching delivery status:', error);
    return null;
  }
};

export default app;
