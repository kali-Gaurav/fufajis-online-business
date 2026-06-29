const { Pool } = require('pg');
const readline = require('readline');
const fs = require('fs');
const path = require('path');
const axios = require('axios');
const { OAuth2Client } = require('google-auth-library');

async function prompt(query) {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    return new Promise(resolve => rl.question(query, ans => {
        rl.close();
        resolve(ans);
    }));
}

function unpackValue(val) {
    if (!val) return null;
    if (val.stringValue !== undefined) return val.stringValue;
    if (val.integerValue !== undefined) return parseInt(val.integerValue, 10);
    if (val.doubleValue !== undefined) return parseFloat(val.doubleValue);
    if (val.booleanValue !== undefined) return val.booleanValue;
    if (val.timestampValue !== undefined) return new Date(val.timestampValue);
    if (val.nullValue !== undefined) return null;
    if (val.arrayValue !== undefined) return (val.arrayValue.values || []).map(v => unpackValue(v));
    if (val.mapValue !== undefined) {
        const res = {};
        for (const k in (val.mapValue.fields || {})) {
            res[k] = unpackValue(val.mapValue.fields[k]);
        }
        return res;
    }
    return val;
}

function unpackDocument(doc) {
    const res = {};
    if (!doc || !doc.fields) return res;
    for (const k in doc.fields) {
        res[k] = unpackValue(doc.fields[k]);
    }
    return res;
}

function parseToDate(val) {
    if (!val) return null;
    if (val instanceof Date) return val;
    if (typeof val === 'string') return new Date(val);
    if (val.seconds !== undefined) return new Date(val.seconds * 1000);
    return new Date(val);
}

async function runDataMigration() {
    console.log('--- AWS RDS Data Migration: Firestore -> PostgreSQL (REST API Version) ---');

    // 1. Initialize Firebase Auth using local configstore token
    const homeDir = process.env.USERPROFILE || process.env.HOME || 'C:\\Users\\Gaurav Nagar';
    const firebaseConfigPath = path.join(homeDir, '.config', 'configstore', 'firebase-tools.json');
    console.log(`Reading Firebase configuration from: ${firebaseConfigPath}`);
    
    let refreshToken = null;
    if (fs.existsSync(firebaseConfigPath)) {
        const config = JSON.parse(fs.readFileSync(firebaseConfigPath, 'utf8'));
        refreshToken = config.tokens?.refresh_token;
    }
    
    if (!refreshToken) {
        console.error('❌ Failed to find Firebase CLI refresh token. Please run "npx firebase login --reauth" in your terminal first.');
        process.exit(1);
    }
    
    const authClient = new OAuth2Client(
        "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
        "j9iVZfS8kkCEFUPaAeJV0sAi"
    );
    authClient.setCredentials({ refresh_token: refreshToken });
    
    let accessToken = '';
    try {
        console.log('Refreshing Firebase access token...');
        const tokenRes = await authClient.getAccessToken();
        accessToken = tokenRes.token;
        console.log('Firebase authentication successful!');
    } catch (err) {
        console.error(`❌ Failed to refresh Firebase access token: ${err.message}`);
        process.exit(1);
    }
    
    const projectId = 'fufaji-online-business';
    const firestoreUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

    // 2. Database Connection setup
    const host = process.env.RDS_HOST || await prompt('RDS Host: ');
    const port = process.env.RDS_PORT || await prompt('RDS Port [5432]: ') || '5432';
    const database = process.env.RDS_DB || await prompt('RDS Database Name [postgres]: ') || 'postgres';
    const user = process.env.RDS_USER || await prompt('RDS Username [dbmasteruser]: ') || 'dbmasteruser';
    const password = process.env.RDS_PASSWORD || await prompt('RDS Password: ');
 
    const pool = new Pool({
        host, port: parseInt(port, 10), user, password, database,
        ssl: { rejectUnauthorized: false }
    });

    try {
        console.log('\nConnecting to AWS RDS...');
        await pool.query('SELECT 1');
        console.log('Connected successfully!');

        // 2.5 Migrate Users first (required to avoid foreign key errors on riders/tasks)
        console.log('\n--- Migrating Users ---');
        let firestoreUsers = [];
        try {
            const queryRes = await axios.post(`${firestoreUrl}:runQuery`, {
                structuredQuery: {
                    from: [{ collectionId: 'users' }]
                }
            }, {
                headers: { Authorization: `Bearer ${accessToken}` }
            });
            const docs = queryRes.data || [];
            firestoreUsers = docs.filter(d => d.document).map(d => unpackDocument(d.document));
        } catch (err) {
            console.error(`❌ Failed to fetch users from Firestore: ${err.message}`);
            process.exit(1);
        }
        console.log(`Found ${firestoreUsers.length} users in Firestore.`);

        for (const u of firestoreUsers) {
            if (!u.id) continue;
            
            // Map UserRole.xxx -> xxx
            let role = (u.role || 'customer').toString().replace('UserRole.', '');
            if (role === 'shopOwner') role = 'owner';
            
            const validRoles = ['customer','employee','rider','dispatcher','branchManager','owner','superAdmin'];
            if (!validRoles.includes(role)) {
                role = 'customer';
            }

            console.log(`Migrating user: ${u.name || u.id} (Role: ${role})`);

            await pool.query(`
                INSERT INTO users (
                    firebase_uid, phone, email, name, role, 
                    wallet_balance, cod_limit, loyalty_points, referral_code, 
                    referred_by, is_active, is_verified, metadata, created_at, updated_at
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
                ON CONFLICT (firebase_uid) DO UPDATE SET
                    phone = EXCLUDED.phone,
                    email = EXCLUDED.email,
                    name = EXCLUDED.name,
                    role = EXCLUDED.role,
                    updated_at = NOW()
            `, [
                u.id, u.phoneNumber || null, u.email || null, u.name || null, role,
                u.walletBalance || 0, u.codLimit || 0, u.rewardPoints || 0, u.referralCode || null,
                u.referredBy || null, u.isActive !== false, u.isVerified === true, 
                JSON.stringify(u.metadata || {}), parseToDate(u.createdAt) || new Date(), 
                parseToDate(u.updatedAt) || new Date()
            ]);
        }
        console.log('✅ Users migration completed.');

        // 3. Migrate Riders
        console.log('\n--- Migrating Riders & Live Location ---');
        const ridersRes = await pool.query("SELECT id, firebase_uid, name FROM users WHERE role = 'rider'");
        const riders = ridersRes.rows;
        console.log(`Found ${riders.length} riders registered in PostgreSQL.`);

        for (const rider of riders) {
            console.log(`Processing rider: ${rider.name || rider.firebase_uid} (ID: ${rider.id})`);
            
            let isOnline = false;
            let latitude = null;
            let longitude = null;
            let speed = 0.0;
            let heading = 0.0;
            let batteryLevel = 100.0;
            let currentZone = null;
            let updatedAt = new Date();

            try {
                const queryRes = await axios.post(`${firestoreUrl}:runQuery`, {
                    structuredQuery: {
                        from: [{ collectionId: 'attendance' }],
                        where: {
                            compositeFilter: {
                                op: 'AND',
                                filters: [
                                    {
                                        fieldFilter: {
                                            field: { fieldPath: 'riderId' },
                                            op: 'EQUAL',
                                            value: { stringValue: rider.firebase_uid }
                                        }
                                    },
                                    {
                                        fieldFilter: {
                                            field: { fieldPath: 'status' },
                                            op: 'EQUAL',
                                            value: { stringValue: 'active' }
                                        }
                                    }
                                ]
                            }
                        },
                        limit: 1
                    }
                }, {
                    headers: { Authorization: `Bearer ${accessToken}` }
                });

                const docs = queryRes.data || [];
                const activeDoc = docs.find(d => d.document);
                if (activeDoc) {
                    const attData = unpackDocument(activeDoc.document);
                    isOnline = true;
                    latitude = attData.clockInLatitude || null;
                    longitude = attData.clockInLongitude || null;
                    console.log(`  -> Rider is clocked in. Lat: ${latitude}, Lng: ${longitude}`);
                }
            } catch (err) {
                console.error(`  ⚠️ Failed to check attendance for rider ${rider.name || rider.firebase_uid}: ${err.message}`);
            }

            // Upsert into rider_profiles
            await pool.query(`
                INSERT INTO rider_profiles (
                    id, capacity, success_rate, active_load, is_online, 
                    latitude, longitude, speed, heading, battery_level, 
                    current_zone, updated_at
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                ON CONFLICT (id) DO UPDATE SET
                    is_online = EXCLUDED.is_online,
                    latitude = COALESCE(EXCLUDED.latitude, rider_profiles.latitude),
                    longitude = COALESCE(EXCLUDED.longitude, rider_profiles.longitude),
                    updated_at = NOW()
            `, [
                rider.id, 5, 100.0, 0, isOnline,
                latitude, longitude, speed, heading, batteryLevel,
                currentZone, updatedAt
            ]);
        }
        console.log('✅ Riders migration completed.');

        // 4. Migrate Employee Tasks
        console.log('\n--- Migrating Employee Tasks ---');
        let tasks = [];
        try {
            const queryRes = await axios.post(`${firestoreUrl}:runQuery`, {
                structuredQuery: {
                    from: [{ collectionId: 'employee_tasks', allDescendants: true }]
                }
            }, {
                headers: { Authorization: `Bearer ${accessToken}` }
            });
            const docs = queryRes.data || [];
            tasks = docs.filter(d => d.document).map(d => unpackDocument(d.document));
        } catch (err) {
            console.error(`❌ Failed to fetch employee tasks from Firestore: ${err.message}`);
            process.exit(1);
        }
        console.log(`Found ${tasks.length} tasks in Firestore.`);

        let taskMigratedCount = 0;
        for (const t of tasks) {
            const taskId = t.id;
            if (!taskId) continue;

            const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
            const branchId = uuidRegex.test(t.branchId) ? t.branchId : null;
            const shopId = uuidRegex.test(t.shopId) ? t.shopId : null;

            const type = (t.type || 'packing').toLowerCase();
            const priority = (t.priority || 'medium').toLowerCase();
            const status = (t.status || 'released').toLowerCase();

            // We must find the corresponding database user uuid for assignedUserId
            let assignedUserId = null;
            if (t.assignedUserId) {
                const userRes = await pool.query('SELECT id FROM users WHERE firebase_uid = $1', [t.assignedUserId]);
                if (userRes.rows.length > 0) {
                    assignedUserId = userRes.rows[0].id;
                }
            }

            const title = t.title || 'Untitled Task';
            const description = t.description || '';
            const referenceId = t.referenceId || null;
            const createdAt = parseToDate(t.createdAt) || new Date();
            const startedAt = parseToDate(t.startedAt);
            const completedAt = parseToDate(t.completedAt);
            const timeEstimateMinutes = parseInt(t.timeEstimateMinutes, 10) || 15;
            
            const latitude = t.latitude ? parseFloat(t.latitude) : null;
            const longitude = t.longitude ? parseFloat(t.longitude) : null;
            const payloadWeight = t.payloadWeight ? parseFloat(t.payloadWeight) : 0.0;
            const payoutAmount = t.payoutAmount ? parseFloat(t.payoutAmount) : 0.0;

            try {
                let taskIdUuid = uuidRegex.test(taskId) ? taskId : null;

                if (taskIdUuid) {
                    await pool.query(`
                        INSERT INTO employee_tasks (
                            id, firestore_id, title, description, type, priority, status,
                            assigned_user_id, assigned_user_name, branch_id, shop_id, reference_id,
                            created_at, started_at, completed_at, time_estimate_minutes,
                            latitude, longitude, payload_weight, payout_amount, updated_at
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, NOW())
                        ON CONFLICT (id) DO UPDATE SET
                            status = EXCLUDED.status,
                            assigned_user_id = EXCLUDED.assigned_user_id,
                            assigned_user_name = EXCLUDED.assigned_user_name,
                            started_at = EXCLUDED.started_at,
                            completed_at = EXCLUDED.completed_at,
                            updated_at = NOW()
                    `, [
                        taskIdUuid, taskId, title, description, type, priority, status,
                        assignedUserId, t.assignedUserName || null, branchId, shopId, referenceId,
                        createdAt, startedAt, completedAt, timeEstimateMinutes,
                        latitude, longitude, payloadWeight, payoutAmount
                    ]);
                } else {
                    await pool.query(`
                        INSERT INTO employee_tasks (
                            firestore_id, title, description, type, priority, status,
                            assigned_user_id, assigned_user_name, branch_id, shop_id, reference_id,
                            created_at, started_at, completed_at, time_estimate_minutes,
                            latitude, longitude, payload_weight, payout_amount, updated_at
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, NOW())
                        ON CONFLICT (firestore_id) DO UPDATE SET
                            status = EXCLUDED.status,
                            assigned_user_id = EXCLUDED.assigned_user_id,
                            assigned_user_name = EXCLUDED.assigned_user_name,
                            started_at = EXCLUDED.started_at,
                            completed_at = EXCLUDED.completed_at,
                            updated_at = NOW()
                    `, [
                        taskId, title, description, type, priority, status,
                        assignedUserId, t.assignedUserName || null, branchId, shopId, referenceId,
                        createdAt, startedAt, completedAt, timeEstimateMinutes,
                        latitude, longitude, payloadWeight, payoutAmount
                    ]);
                }
                taskMigratedCount++;
            } catch (err) {
                console.error(`  ❌ Failed to migrate task ${taskId}: ${err.message}`);
            }
        }
        console.log(`✅ Tasks migration completed. Successfully migrated ${taskMigratedCount} tasks.`);

    } catch (e) {
        console.error('\n❌ Migration Failed:', e.message);
    } finally {
        await pool.end();
        console.log('\nDatabase connection pool closed.');
    }
}

runDataMigration();
