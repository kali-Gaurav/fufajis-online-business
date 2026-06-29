const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.RDS_HOST,
  port: 5432,
  user: 'dbmasteruser',
  password: process.env.RDS_PASSWORD,
  database: 'postgres',
  ssl: { rejectUnauthorized: false }
});

async function verify() {
  try {
    // List our new tables
    const tables = await pool.query(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name"
    );
    console.log('✅ Tables present in AWS RDS:');
    tables.rows.forEach(r => console.log('  -', r.table_name));

    // Count columns per table
    for (const t of tables.rows) {
      const cols = await pool.query(
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1 ORDER BY ordinal_position",
        [t.table_name]
      );
      console.log(`\n  ${t.table_name} (${cols.rows.length} columns):`);
      cols.rows.forEach(c => console.log(`    - ${c.column_name} (${c.data_type})`));
    }

    // Check delivery_zones seed
    const zones = await pool.query("SELECT zone_name, zone_code, center_lat, center_lng FROM delivery_zones");
    console.log('\n✅ Delivery Zones seeded:');
    zones.rows.forEach(z => console.log(`  - ${z.zone_name} (${z.zone_code}) @ ${z.center_lat}, ${z.center_lng}`));

  } catch (e) {
    console.error('❌ Verification failed:', e.message);
  } finally {
    await pool.end();
  }
}

verify();
