-- V003__create_schemas.sql
------------------------------------------------------------
-- Create schemas
------------------------------------------------------------

-- shcema app: owned by app_owner
GRANT app_owner TO dbadmin; 
CREATE SCHEMA IF NOT EXISTS app AUTHORIZATION app_owner;

------------------------------------------------------------
-- Set default search_path 
------------------------------------------------------------
ALTER ROLE app_user
SET search_path = app, public;

ALTER ROLE app_readonly
SET search_path = app, public;

------------------------------------------------------------
-- Confirm
------------------------------------------------------------
-- SELECT 
--     schema_name,
--     schema_owner
-- FROM information_schema.schemata
-- WHERE schema_name = 'app';
