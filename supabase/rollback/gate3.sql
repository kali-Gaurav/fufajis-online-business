BEGIN;
DROP FUNCTION IF EXISTS security.is_current_user_admin CASCADE;
DROP FUNCTION IF EXISTS security.user_owns_record CASCADE;
DROP FUNCTION IF EXISTS security.is_service_role CASCADE;

ALTER TABLE security.privileged_credentials DISABLE ROW LEVEL SECURITY;
ALTER TABLE security.privileged_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE security.privileged_devices DISABLE ROW LEVEL SECURITY;
ALTER TABLE security.rate_limits DISABLE ROW LEVEL SECURITY;
ALTER TABLE security.audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE security.password_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE security.schema_metadata DISABLE ROW LEVEL SECURITY;
COMMIT;
