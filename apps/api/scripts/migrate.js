/**
 * migrate.js
 * Runs all SQL migration files in order against the connected database.
 * Usage: node scripts/migrate.js
 * On Railway: set as a one-off command or add to package.json scripts.
 */

require("dotenv").config();
const { Pool } = require("pg");
const fs = require("fs");
const path = require("path");

const connectionString = process.env.DATABASE_URL || process.env.POSTGRES_URL;
const hasFallbackConfig = Boolean(
  process.env.DB_HOST && process.env.DB_NAME && process.env.DB_USER,
);

if (!connectionString && !hasFallbackConfig) {
  throw new Error(
    "No database connection config found. Set DATABASE_URL or POSTGRES_URL, or DB_HOST/DB_NAME/DB_USER/DB_PASSWORD.",
  );
}

const pool = connectionString
  ? new Pool({
      connectionString,
      ssl: { rejectUnauthorized: false },
    })
  : new Pool({
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT || "5432", 10),
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
    });

// Migrations in the order they must run
const MIGRATIONS = [
  "001_create_users.sql",
  "002_create_establishments.sql",
  "003_create_beneficiaries.sql",
  "004_create_beneficiary_accounts.sql",
  "005_create_verification_logs.sql",
  "006_create_fraud_flags.sql",
  "007_create_disputes.sql",
  "008_create_notifications.sql",
  "009_create_audit_logs.sql",
  "010_add_pin_to_beneficiary_accounts.sql",
  "011_add_disability_type.sql",
  "012_add_staff_audit_actions.sql",
  "013_fraud_flags_denormalize.sql",
  "014_fraud_flags_duplicate_detection.sql",
  "015_image_path_to_text.sql",
  "016_add_login_lockout.sql",
  "017_add_missing_audit_actions.sql",
  "018_establishment_permit_and_reset.sql",
  "019_add_fraud_restore_audit_action.sql",
  "020_add_establishment_bulk_import.sql",
  "021_cross_validation_and_normalization.sql",
  "022_staff_alerts.sql",
  "023_unique_person_index.sql",
  "024_add_beneficiary_contact_fields.sql",
  "025_partial_unique_person_index.sql",
  "026_verification_logs_immutability.sql",
  "027_staff_password_reset.sql",
  "028_add_id_format_to_verification_logs.sql",
  "029_add_synced_from_offline_to_verification_logs.sql",
  "030_add_beneficiary_deleted_audit_action.sql",
  "031_allow_beneficiary_fk_cleanup_in_verification_logs.sql",
  "032_preserve_immutable_logs_on_beneficiary_delete.sql",
  "033_add_reported_establishment_name_to_disputes.sql",
  "034_add_other_dispute_type.sql",
  "035_add_reference_numbers.sql",
];

// Migration files are co-located inside apps/api/migrations/
// so they are included when Railway deploys the apps/api root directory.
const MIGRATIONS_DIR = path.resolve(__dirname, "../migrations");

async function runMigrations() {
  const client = await pool.connect();
  try {
    console.log("🚀 Starting iDetect database migrations...\n");

    // Enable pgcrypto for UUID generation
    await client.query('CREATE EXTENSION IF NOT EXISTS "pgcrypto"');
    console.log("✓ pgcrypto extension ready");

    for (const filename of MIGRATIONS) {
      const filepath = path.join(MIGRATIONS_DIR, filename);

      if (!fs.existsSync(filepath)) {
        console.warn(`⚠  Skipping ${filename} — file not found`);
        continue;
      }

      const sql = fs.readFileSync(filepath, "utf8");

      try {
        await client.query(sql);
        console.log(`✓ ${filename}`);
      } catch (err) {
        // IF NOT EXISTS / duplicate column errors are safe to ignore —
        // they mean this migration already ran
        if (
          err.code === "42P07" || // duplicate_table
          err.code === "42701" || // duplicate_column
          err.code === "42710" || // duplicate_object (index, constraint)
          err.message?.includes("already exists")
        ) {
          console.log(`~ ${filename} (already applied, skipping)`);
        } else {
          console.error(`✗ ${filename} FAILED: ${err.message}`);
          throw err;
        }
      }
    }

    console.log("\n=== iDetect schema ready ===");
  } finally {
    client.release();
    await pool.end();
  }
}

runMigrations().catch((err) => {
  console.error("Migration failed:", err);
  process.exit(1);
});
