-- V002__create_roles.sql
------------------------------------------------------------
-- Create application roles.
------------------------------------------------------------

------------------------------------------------------------
-- app_owner: owns objects, no login
------------------------------------------------------------
DO
$do$
BEGIN
   -- check if exits
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE rolname = 'app_owner'
   ) THEN
      RAISE NOTICE 'Role "app_owner" already exists. Skipping.';
   ELSE
   -- create role
      CREATE ROLE app_owner
         NOLOGIN
         INHERIT;
      COMMENT ON ROLE app_owner IS 'Owns application schemas and tables; no login.';
   END IF;
END
$do$;

COMMENT ON ROLE app_owner IS
  'Owns application schemas and tables; no direct login.';

------------------------------------------------------------
-- app_user: application login (read/write)
------------------------------------------------------------
DO
$do$
BEGIN
   -- if exists
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE rolname = 'app_user'
   ) THEN
      RAISE NOTICE 'Role "app_user" already exists. Skipping.';
   ELSE
   -- create role
      CREATE ROLE app_user
         LOGIN
         PASSWORD '${app_user_password}'
         NOSUPERUSER
         NOCREATEDB
         NOCREATEROLE
         INHERIT;
         -- CONNECTION LIMIT 50;
      COMMENT ON ROLE app_user IS 'Primary application login with read/write access.';
   END IF;
END
$do$;

------------------------------------------------------------
-- app_readonly: read-only login
------------------------------------------------------------
DO
$do$
BEGIN
   -- check if exist
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE rolname = 'app_readonly'
   ) THEN
      RAISE NOTICE 'Role "app_readonly" already exists. Skipping.';
   ELSE
   -- create role
      CREATE ROLE app_readonly
         LOGIN
         PASSWORD '${app_readonly_password}'
         NOSUPERUSER
         NOCREATEDB
         NOCREATEROLE
         INHERIT
         CONNECTION LIMIT 20;
      COMMENT ON ROLE app_readonly IS 'Read-only login for reporting/BI.';
   END IF;
END
$do$;


-- ------------------------------------------------------------
-- -- Confirm
-- ------------------------------------------------------------
-- SELECT
--     rolname,
--     rolcanlogin,
--     rolsuper,
--     rolcreaterole,
--     rolcreatedb,
--     rolinherit,
--     rolconnlimit
-- FROM
--     pg_roles
-- WHERE
--     rolname IN ('app_owner', 'app_user', 'app_readonly')
-- ORDER BY
--     rolname;