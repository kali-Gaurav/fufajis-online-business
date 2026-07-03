import {
  GoogleAuthProvider,
  signInWithCredential,
  signOut as firebaseSignOut,
} from 'firebase/auth';
import { auth, createUserIfMissing } from './FirebaseService';

/**
 * AuthService - Google Sign-In with user creation
 * FIX: Proper auth flow
 */

export const signInWithGoogle = async () => {
  try {
    console.log('🔐 Starting Google Sign-In...');

    // Note: In React Native, use expo-google-app-auth or expo-web-browser
    // For now, this is a placeholder
    // You'll integrate with expo-google-app-auth in production

    const credential = GoogleAuthProvider.credential(
      'idToken',
      'accessToken'
    );

    const result = await signInWithCredential(auth, credential);
    const user = result.user;

    console.log('✅ Firebase auth successful:', user.uid);

    // Create user document (FIX: auto-creation on first login)
    await createUserIfMissing(user);

    return {
      user,
      isLoggedIn: true,
    };
  } catch (error) {
    console.error('❌ Google Sign-In error:', error);
    throw new Error(`Sign-in failed: ${error.message}`);
  }
};

export const logout = async () => {
  try {
    console.log('👋 Signing out...');
    await firebaseSignOut(auth);
    console.log('✅ Signed out');
    return true;
  } catch (error) {
    console.error('❌ Logout error:', error);
    throw error;
  }
};

export const getCurrentUser = () => {
  return auth.currentUser;
};

export default {
  signInWithGoogle,
  logout,
  getCurrentUser,
};
