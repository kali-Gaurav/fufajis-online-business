const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { Pool } = require('pg');
const { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

/**
 * ═══════════════════════════════════════════════════════════════════════
 * SUPABASE / GEMINI BACKEND PROXY (RDS / S3 / Bedrock Fallback)
 * ═══════════════════════════════════════════════════════════════════════
 * All secrets live in Secret Manager. They are bound at deploy time
 * and accessed via process.env.
 */

function validateAppCheck(context) {
    if (!context.app) {
        throw new functions.https.HttpsError(
            'failed-precondition',
            'The function must be called from an App Check verified app.'
        );
    }
}

/**
 * Requires the caller to be authenticated AND have the admin/owner role.
 * Checks custom claims first (fast path), falls back to Firestore.
 */
async function requireAdmin(context) {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'The function must be called while authenticated.'
        );
    }

    const claimRole = context.auth.token?.role;
    if (claimRole === 'UserRole.admin' || claimRole === 'UserRole.owner') {
        return;
    }

    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const role = userDoc.exists ? userDoc.data().role : null;

    if (role !== 'UserRole.admin' && role !== 'UserRole.owner') {
        throw new functions.https.HttpsError(
            'permission-denied',
            'Only admins or the owner can access backend services.'
        );
    }
}

// ─────────────────────────────────────────────────────────────────────────
// Lazy singletons (created on first use so cold starts without config don't crash)
// ─────────────────────────────────────────────────────────────────────────

let _pgPool = null;
/**
 * Returns a lazily-created pg.Pool for the app's Postgres database (Supabase).
 */
function getPgPool() {
    if (_pgPool) return _pgPool;

    const connectionString = process.env.RDS_CONNECTION_STRING;
    const host = connectionString ? null : (process.env.RDS_HOST || process.env.SUPABASE_HOST);
    
    if (!connectionString && !host) {
        throw new functions.https.HttpsError('failed-precondition', 'PostgreSQL database connection is not configured on the server.');
    }

    const maxPool = parseInt(process.env.RDS_POOL_MAX || '3', 10);

    const config = connectionString 
        ? { connectionString, ssl: { rejectUnauthorized: false }, max: maxPool }
        : {
            host,
            port: parseInt(process.env.RDS_PORT || '5432', 10),
            user: process.env.RDS_USER,
            password: process.env.RDS_PASSWORD,
            database: process.env.RDS_DATABASE || 'postgres',
            ssl: { rejectUnauthorized: false },
            max: maxPool,
            idleTimeoutMillis: 30000,
            connectionTimeoutMillis: 10000,
          };

    _pgPool = new Pool(config);
    return _pgPool;
}

let _s3Client = null;
function getS3Client() {
    if (_s3Client) return _s3Client;

    const accessKeyId = process.env.SUPABASE_S3_ACCESS_KEY;
    const secretAccessKey = process.env.SUPABASE_S3_SECRET_KEY;
    const endpoint = process.env.SUPABASE_S3_ENDPOINT || 'https://orfikmmpbboesbxdiwzb.storage.supabase.co/storage/v1/s3';
    
    if (!accessKeyId) {
        throw new functions.https.HttpsError('failed-precondition', 'Supabase S3 is not configured on the server.');
    }

    _s3Client = new S3Client({
        region: 'ap-south-1',
        endpoint: endpoint,
        credentials: {
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
        },
        forcePathStyle: true,
    });
    return _s3Client;
}

const ALLOWED_TABLES = new Set([
    'orders', 'order_items', 'products', 'customers', 'inventory_log',
    'analytics_events', 'payouts', 'reviews',
]);

const RDS_SECRETS = ['RDS_CONNECTION_STRING', 'RDS_HOST', 'RDS_PORT', 'RDS_USER', 'RDS_PASSWORD', 'RDS_DATABASE'];
const S3_SECRETS = ['SUPABASE_S3_ACCESS_KEY', 'SUPABASE_S3_SECRET_KEY', 'SUPABASE_S3_ENDPOINT', 'SUPABASE_URL'];

/**
 * ═══════════════════════════════════════════════════════════════════════
 * CONTACTS MANAGEMENT — Secure access to Supabase Postgres contacts table.
 * ═══════════════════════════════════════════════════════════════════════
 */
exports.getContacts = functions.runWith({ secrets: RDS_SECRETS }).https.onCall(async (data, context) => {
    validateAppCheck(context);
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');

    try {
        const pool = getPgPool();
        const result = await pool.query(
            'SELECT * FROM contacts WHERE user_id = $1 ORDER BY name ASC',
            [context.auth.uid]
        );
        return { success: true, rows: result.rows };
    } catch (error) {
        throw new functions.https.HttpsError('internal', error.message);
    }
});

exports.addContact = functions.runWith({ secrets: RDS_SECRETS }).https.onCall(async (data, context) => {
    validateAppCheck(context);
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');

    const { name, phone_number, email, relationship, address } = data;
    if (!name || !phone_number) throw new functions.https.HttpsError('invalid-argument', 'Name and phone required.');

    try {
        const pool = getPgPool();
        await pool.query(
            'INSERT INTO contacts (user_id, name, phone_number, email, relationship, address) VALUES ($1, $2, $3, $4, $5, $6)',
            [context.auth.uid, name, phone_number, email, relationship, address]
        );
        return { success: true };
    } catch (error) {
        throw new functions.https.HttpsError('internal', error.message);
    }
});

exports.deleteContact = functions.runWith({ secrets: RDS_SECRETS }).https.onCall(async (data, context) => {
    validateAppCheck(context);
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');

    const { id } = data;
    if (!id) throw new functions.https.HttpsError('invalid-argument', 'ID required.');

    try {
        const pool = getPgPool();
        await pool.query('DELETE FROM contacts WHERE id = $1 AND user_id = $2', [id, context.auth.uid]);
        return { success: true };
    } catch (error) {
        throw new functions.https.HttpsError('internal', error.message);
    }
});

/**
 * ═══════════════════════════════════════════════════════════════════════
 * rdsQuery — Parameterized, read-mostly access to Postgres.
 * ═══════════════════════════════════════════════════════════════════════
 */
exports.rdsQuery = functions.runWith({ secrets: RDS_SECRETS }).https.onCall(async (data, context) => {
    validateAppCheck(context);
    await requireAdmin(context);

    const { sql, params = [], allowWrite = false } = data || {};

    if (!sql || typeof sql !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'A SQL string is required.');
    }

    const normalized = sql.trim().toLowerCase();
    const isWrite = /^(insert|update|delete|drop|alter|truncate|create)\b/.test(normalized);

    if (isWrite && !allowWrite) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'Write queries require allowWrite: true and admin privileges.'
        );
    }

    try {
        const pool = getPgPool();
        const result = await pool.query(sql, params);
        return {
            success: true,
            rowCount: result.rowCount,
            rows: result.rows,
            fields: (result.fields || []).map((f) => f.name),
        };
    } catch (error) {
        console.error('[rdsQuery] Error:', error);
        throw new functions.https.HttpsError('internal', `Postgres query failed: ${error.message}`);
    }
});

/**
 * ═══════════════════════════════════════════════════════════════════════
 * getS3UploadUrl — Returns a short-lived presigned PUT URL for Supabase S3.
 * ═══════════════════════════════════════════════════════════════════════
 */
exports.getS3UploadUrl = functions.runWith({ secrets: S3_SECRETS }).https.onCall(async (data, context) => {
    validateAppCheck(context);
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
    }

    const { key, contentType = 'application/octet-stream', expiresIn = 900 } = data || {};
    if (!key || typeof key !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'A destination "key" is required.');
    }

    // Restrict non-admins to their own folder: uploads/{uid}/...
    const claimRole = context.auth.token?.role;
    const isAdmin = claimRole === 'UserRole.admin' || claimRole === 'UserRole.owner';
    if (!isAdmin && !key.startsWith(`uploads/${context.auth.uid}/`)) {
        throw new functions.https.HttpsError(
            'permission-denied',
            `Uploads must be placed under uploads/${context.auth.uid}/`
        );
    }

    try {
        const bucket = process.env.SUPABASE_S3_BUCKET || 'uploads';
        const client = getS3Client();

        const command = new PutObjectCommand({
            Bucket: bucket,
            Key: key,
            ContentType: contentType,
        });

        const url = await getSignedUrl(client, command, { expiresIn: Math.min(expiresIn, 3600) });
        
        const projectId = process.env.SUPABASE_URL 
            ? new URL(process.env.SUPABASE_URL).hostname.split('.')[0] 
            : 'orfikmmpbboesbxdiwzb';
        const publicUrl = `https://${projectId}.supabase.co/storage/v1/object/public/${bucket}/${key}`;

        return { success: true, uploadUrl: url, key, bucket, publicUrl, expiresIn };
    } catch (error) {
        console.error('[getS3UploadUrl] Error:', error);
        throw new functions.https.HttpsError('internal', `Failed to create upload URL: ${error.message}`);
    }
});

/**
 * ═══════════════════════════════════════════════════════════════════════
 * getS3DownloadUrl — Returns a short-lived presigned GET URL for Supabase S3.
 * ═══════════════════════════════════════════════════════════════════════
 */
exports.getS3DownloadUrl = functions.runWith({ secrets: S3_SECRETS }).https.onCall(async (data, context) => {
    validateAppCheck(context);
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
    }

    const { key, expiresIn = 3600 } = data || {};
    if (!key || typeof key !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'A "key" is required.');
    }

    const claimRole = context.auth.token?.role;
    const isAdmin = claimRole === 'UserRole.admin' || claimRole === 'UserRole.owner';
    if (!isAdmin && !key.startsWith(`uploads/${context.auth.uid}/`)) {
        throw new functions.https.HttpsError(
            'permission-denied',
            `You may only access your own files under uploads/${context.auth.uid}/`
        );
    }

    try {
        const bucket = process.env.SUPABASE_S3_BUCKET || 'uploads';
        const client = getS3Client();

        const command = new GetObjectCommand({ Bucket: bucket, Key: key });
        const url = await getSignedUrl(client, command, { expiresIn: Math.min(expiresIn, 3600) });

        return { success: true, downloadUrl: url, key, bucket, expiresIn };
    } catch (error) {
        console.error('[getS3DownloadUrl] Error:', error);
        throw new functions.https.HttpsError('internal', `Failed to create download URL: ${error.message}`);
    }
});

/**
 * ═══════════════════════════════════════════════════════════════════════
 * deleteS3Object — Admin-only object deletion in Supabase S3.
 * ═══════════════════════════════════════════════════════════════════════
 */
exports.deleteS3Object = functions.runWith({ secrets: S3_SECRETS }).https.onCall(async (data, context) => {
    validateAppCheck(context);
    await requireAdmin(context);

    const { key } = data || {};
    if (!key || typeof key !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'A "key" is required.');
    }

    try {
        const bucket = process.env.SUPABASE_S3_BUCKET || 'uploads';
        const client = getS3Client();

        await client.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
        return { success: true, key };
    } catch (error) {
        console.error('[deleteS3Object] Error:', error);
        throw new functions.https.HttpsError('internal', `Failed to delete object: ${error.message}`);
    }
});

/**
 * ═══════════════════════════════════════════════════════════════════════
 * bedrockGenerate — Proxies a prompt to Gemini (repointed for AWS removal).
 * ═══════════════════════════════════════════════════════════════════════
 */
exports.bedrockGenerate = functions.runWith({ secrets: ['GEMINI_API_KEY'] }).https.onCall(async (data, context) => {
    validateAppCheck(context);
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
    }

    const { prompt } = data || {};
    if (!prompt || typeof prompt !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'A "prompt" string is required.');
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
        throw new functions.https.HttpsError('failed-precondition', 'Gemini API key is not configured.');
    }

    try {
        const { GoogleGenerativeAI } = require('@google/generative-ai');
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
        
        const result = await model.generateContent(prompt);
        const response = await result.response;
        const text = response.text();

        return { success: true, text: text };
    } catch (error) {
        console.error('[bedrockGenerate] Error:', error);
        throw new functions.https.HttpsError('internal', `Request failed: ${error.message}`);
    }
});

/**
 * ═══════════════════════════════════════════════════════════════════════
 * verifyBackendHealth — Live connectivity check for Supabase Postgres, Supabase S3, and Gemini.
 * ═══════════════════════════════════════════════════════════════════════
 */
exports.verifyBackendHealth = functions.runWith({
    secrets: [
        'RDS_CONNECTION_STRING', 'RDS_HOST', 'RDS_PORT', 'RDS_USER', 'RDS_PASSWORD', 'RDS_DATABASE',
        'SUPABASE_S3_ACCESS_KEY', 'SUPABASE_S3_SECRET_KEY', 'SUPABASE_S3_ENDPOINT',
        'GEMINI_API_KEY'
    ]
}).https.onCall(async (data, context) => {
    validateAppCheck(context);
    await requireAdmin(context);

    const results = {
        rds: { configured: false, reachable: false },
        s3: { configured: false, reachable: false },
        bedrock: { configured: false, reachable: false },
    };

    // RDS/Postgres
    try {
        results.rds.configured = !!(process.env.RDS_CONNECTION_STRING || process.env.RDS_HOST);
        if (results.rds.configured) {
            const start = Date.now();
            const pool = getPgPool();
            await pool.query('SELECT 1');
            results.rds.reachable = true;
            results.rds.latencyMs = Date.now() - start;
        }
    } catch (error) {
        results.rds.error = error.message;
    }

    // Supabase S3
    try {
        results.s3.configured = !!process.env.SUPABASE_S3_ACCESS_KEY;
        if (results.s3.configured) {
            const start = Date.now();
            const client = getS3Client();
            const bucket = process.env.SUPABASE_S3_BUCKET || 'uploads';
            await getSignedUrl(client, new PutObjectCommand({ Bucket: bucket, Key: '__healthcheck__' }), { expiresIn: 60 });
            results.s3.reachable = true;
            results.s3.latencyMs = Date.now() - start;
        }
    } catch (error) {
        results.s3.error = error.message;
    }

    // Gemini
    try {
        results.bedrock.configured = !!process.env.GEMINI_API_KEY;
        if (results.bedrock.configured) {
            const start = Date.now();
            const { GoogleGenerativeAI } = require('@google/generative-ai');
            const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
            const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
            await model.generateContent('ping');
            results.bedrock.reachable = true;
            results.bedrock.latencyMs = Date.now() - start;
        }
    } catch (error) {
        results.bedrock.error = error.message;
    }

    return { success: true, results, checkedAt: new Date().toISOString() };
});

exports.getPgPool = getPgPool;
exports.getS3Client = getS3Client;
exports.requireAdmin = requireAdmin;
