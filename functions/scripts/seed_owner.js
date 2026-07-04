const admin = require('firebase-admin');
const bcrypt = require('bcrypt');
require('dotenv').config();

// Initialize Firebase Admin (Assumes GOOGLE_APPLICATION_CREDENTIALS is set, or running locally with default creds)
if (!admin.apps.length) {
    admin.initializeApp();
}

async function seedOwner() {
    const db = admin.firestore();

    const loginId = process.env.OWNER_ID || 'OWNER001';
    const plainTextPassword = process.env.OWNER_PASSWORD || 'SuperSecretOwnerPassword123!';
    const role = 'owner';
    const userId = 'owner_root_uid'; // Unique root UID

    console.log(`Seeding root owner with ID: ${loginId}`);

    try {
        // Hash the password securely
        const saltRounds = 10;
        const passwordHash = await bcrypt.hash(plainTextPassword, saltRounds);

        // 1. Create the user profile in `users`
        const userRef = db.collection('users').doc(userId);
        await userRef.set({
            name: 'Root Owner',
            role: role,
            isActive: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('✅ Created root owner profile in users collection.');

        // 2. Create the credentials in `staff_credentials`
        // We use loginId as the document ID for quick lookups if needed, 
        // or just let it auto-generate and query by loginId.
        const credRef = db.collection('staff_credentials').doc(loginId);
        await credRef.set({
            userId: userId,
            loginId: loginId,
            pinHash: passwordHash, // Storing password hash in pinHash field for unified login
            role: role,
            status: 'active',
            failedAttempts: 0,
            lockedUntil: null,
            createdBy: 'system_bootstrap',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ Stored credentials securely for ${loginId}.`);

        console.log('Seeding complete. You can now login as the owner.');
    } catch (error) {
        console.error('Error seeding owner:', error);
    }
}

seedOwner().then(() => process.exit());
