import admin from "npm:firebase-admin";

// We read the Firebase service account from the Edge Function environment
// The user will need to set FIREBASE_SERVICE_ACCOUNT in Supabase secrets
let isFirebaseInitialized = false;

function initFirebase() {
  if (isFirebaseInitialized) return;

  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!serviceAccountJson) {
    console.error("Missing FIREBASE_SERVICE_ACCOUNT in environment variables.");
    throw new Error("Server configuration error: Firebase not configured.");
  }

  try {
    const serviceAccount = JSON.parse(serviceAccountJson);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    isFirebaseInitialized = true;
    console.log("Firebase Admin SDK initialized successfully.");
  } catch (error) {
    console.error("Failed to initialize Firebase Admin SDK:", error);
    throw new Error("Server configuration error: Invalid Firebase credentials.");
  }
}

/**
 * Verifies a Firebase JWT token and returns the decoded token.
 * This acts as the Auth Bridge for Edge Functions.
 */
export async function verifyFirebaseToken(token: string) {
  initFirebase();
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    return decodedToken;
  } catch (error) {
    console.error("Error verifying Firebase token:", error);
    throw new Error("Unauthorized");
  }
}

/**
 * Syncs data to Firestore to keep it consistent with PostgreSQL.
 * Handles the dual-write requirement for the mobile app.
 */
export async function syncToFirestore(collectionPath: string, documentId: string, data: any) {
  initFirebase();
  try {
    const db = admin.firestore();
    // Use set with merge to create or update
    await db.collection(collectionPath).doc(documentId).set(data, { merge: true });
    console.log(`Synced document ${documentId} to Firestore collection ${collectionPath}`);
    return true;
  } catch (error) {
    console.error("Error syncing to Firestore:", error);
    // Log but don't throw - PostgreSQL is source of truth
    return false;
  }
}

/**
 * Syncs payment transaction to Firestore
 */
export async function syncPaymentToFirestore(paymentId: string, data: any) {
  return syncToFirestore("payment_transactions", paymentId, data);
}

/**
 * Syncs order to Firestore
 */
export async function syncOrderToFirestore(orderId: string, data: any) {
  return syncToFirestore("orders", orderId, data);
}

/**
 * Syncs product catalog to Firestore (Downstream Sync)
 */
export async function syncProductToFirestore(productId: string, data: any) {
  return syncToFirestore("products", productId, data);
}

/**
 * Syncs inventory to Firestore (e.g. after deduction)
 */
export async function syncInventoryToFirestore(inventoryId: string, data: any) {
  return syncToFirestore("inventory", inventoryId, data);
}

// Export as default object for easier importing
export default {
  verifyFirebaseToken,
  syncToFirestore,
  syncPaymentToFirestore,
  syncOrderToFirestore,
  syncProductToFirestore,
  syncInventoryToFirestore,
};
