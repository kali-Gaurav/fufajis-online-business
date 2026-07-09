BEGIN;
DROP TABLE IF EXISTS security.password_history CASCADE;
DROP TABLE IF EXISTS security.audit_logs CASCADE;
DROP TABLE IF EXISTS security.rate_limits CASCADE;
DROP TABLE IF EXISTS security.privileged_devices CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS security.update_privileged_credentials_timestamp CASCADE;
DROP FUNCTION IF EXISTS security.update_session_activity CASCADE;
DROP FUNCTION IF EXISTS security.auto_deactivate_expired_sessions CASCADE;
DROP FUNCTION IF EXISTS security.enforce_password_history_limit CASCADE;
DROP FUNCTION IF EXISTS security.prevent_audit_modification CASCADE;
DROP FUNCTION IF EXISTS security.cleanup_expired_sessions CASCADE;
DROP FUNCTION IF EXISTS security.get_expired_passwords CASCADE;
DROP FUNCTION IF EXISTS security.reset_user_rate_limit CASCADE;
DROP FUNCTION IF EXISTS security.get_account_status CASCADE;
DROP FUNCTION IF EXISTS security.archive_old_audit_logs CASCADE;
DROP FUNCTION IF EXISTS security.get_schema_statistics CASCADE;
COMMIT;
