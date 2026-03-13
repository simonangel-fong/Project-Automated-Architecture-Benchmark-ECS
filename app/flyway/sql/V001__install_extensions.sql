-- V001__install_extensions.sql
------------------------------------------------------------
-- Install extensions
------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS dblink;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Trigram indexes for fuzzy search (ILIKE + %term%)
CREATE EXTENSION IF NOT EXISTS pg_trgm;