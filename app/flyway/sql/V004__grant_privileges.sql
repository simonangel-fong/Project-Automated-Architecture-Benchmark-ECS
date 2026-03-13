-- V004__grant_privileges.sql
------------------------------------------------------------
-- Grant privileges for schema
------------------------------------------------------------

------------------------------------------------------------
-- Schema privileges: app
------------------------------------------------------------
-- Remove any implicit access for PUBLIC
REVOKE ALL ON SCHEMA app FROM PUBLIC;
-- Grant schema usage to role
GRANT USAGE ON SCHEMA app TO app_user, app_readonly;

------------------------------------------------------------
-- Existing object privileges
------------------------------------------------------------
-- app_user: full DML on existing tables in app schema
GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA app
TO app_user;

-- app_user: sequence access
GRANT USAGE, SELECT
ON ALL SEQUENCES IN SCHEMA app
TO app_user;

-- app_readonly: read-only on existing tables in app schema
GRANT SELECT
ON ALL TABLES IN SCHEMA app
TO app_readonly;


------------------------------------------------------------
-- Future objects privileges 
------------------------------------------------------------
-- Default privilegs:
--  objet: tables in app owned by app_owner
--  user: app_user
--  privileges: SELECT, INSERT, UPDATE, DELETE
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app
    GRANT SELECT, INSERT, UPDATE, DELETE
    ON TABLES
    TO app_user;

-- Default privilegs:
--  objet: sequences in app owned by app_owner
--  user: app_user;
--  privileges: USAGE, SELECT
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app
    GRANT USAGE, SELECT
    ON SEQUENCES
    TO app_user;

-- Default privilegs:
--  objet: tables in app owned by app_owner
--  user: app_readonly;
--  privileges: SELECT
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app
    GRANT SELECT
    ON TABLES
    TO app_readonly;

