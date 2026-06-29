const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

async function prompt(query) {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    return new Promise(resolve => rl.question(query, ans => {
        rl.close();
        resolve(ans);
    }));
}

async function runMigration() {
    console.log('--- AWS RDS PostgreSQL Migration Setup ---');
    console.log('You are about to apply Phase 13 Inventory schema to AWS RDS.');
    
    // Check if env vars exist or prompt for them
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

        const migrationFile = process.argv[2] || '006_phase13_inventory_architecture.sql';
        const sqlPath = path.resolve(__dirname, '../../supabase/migrations', migrationFile);
        console.log(`\nReading SQL migration file: ${sqlPath}`);
        
        if (!fs.existsSync(sqlPath)) {
            throw new Error(`Migration file not found! Ensure it exists at supabase/migrations/${migrationFile}`);
        }

        const sqlContent = fs.readFileSync(sqlPath, 'utf8');

        console.log('Executing migration script on RDS... This might take a moment.');
        // Execute the entire SQL script (pg driver allows multiple statements in one query string)
        await pool.query(sqlContent);
        
        console.log('\n✅ Phase 13 Migration applied to AWS RDS successfully!');
        
    } catch (e) {
        console.error('\n❌ Migration Failed:', e.message);
    } finally {
        await pool.end();
    }
}

runMigration();
