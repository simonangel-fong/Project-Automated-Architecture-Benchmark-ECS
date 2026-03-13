-- V005__create_functions.sql
------------------------------------------------------------
-- Create reusable database functions used across tables.
------------------------------------------------------------

SET LOCAL ROLE app_owner;

------------------------------------------------------------
-- Function: app.fn_set_updated_at
--   To maintain updated_at timestamp for any table that calls it.
------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.fn_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
VOLATILE
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

-- ==========================================
-- Function: fn_upsert_telemetry_latest
--   On each new telemetry_event, update the latest snapshot.
-- ==========================================
CREATE OR REPLACE FUNCTION app.fn_upsert_telemetry_latest()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO app.telemetry_latest (
        device_uuid,
        alias,
        x_coord,
        y_coord,
        device_time,
        system_time_utc
    )
    SELECT
        NEW.device_uuid,
        dr.alias,
        NEW.x_coord,
        NEW.y_coord,
        NEW.device_time,
        NEW.system_time_utc
    FROM app.device_registry AS dr
    WHERE dr.device_uuid = NEW.device_uuid
    ON CONFLICT (device_uuid) DO UPDATE
    SET
        alias       = EXCLUDED.alias,
        x_coord     = EXCLUDED.x_coord,
        y_coord     = EXCLUDED.y_coord,
        device_time = EXCLUDED.device_time,
        system_time_utc = EXCLUDED.system_time_utc
    WHERE app.telemetry_latest.system_time_utc < EXCLUDED.system_time_utc;

    RETURN NEW;
END;
$$;

RESET ROLE;
