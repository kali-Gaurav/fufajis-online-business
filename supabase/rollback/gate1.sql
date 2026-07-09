BEGIN;
DROP TABLE IF EXISTS security.privileged_sessions CASCADE;
DROP TABLE IF EXISTS security.privileged_credentials CASCADE;
DROP TABLE IF EXISTS security.schema_metadata CASCADE;
DROP SCHEMA IF EXISTS security CASCADE;
COMMIT;
