-- V012__create_tb_telemetry_latest.sql
------------------------------------------------------------
-- Create table app.telemetry_latest
--  latest valid position per device, for fast lookup.
------------------------------------------------------------

SET LOCAL ROLE app_owner;

------------------------------------------------------------
-- Table: app.telemetry_latest
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.telemetry_latest (
    device_uuid       UUID             PRIMARY KEY REFERENCES app.device_registry(device_uuid) ON DELETE CASCADE,
    alias             VARCHAR(64),     
    x_coord           DOUBLE PRECISION NOT NULL,
    y_coord           DOUBLE PRECISION NOT NULL,
    device_time       TIMESTAMPTZ      NOT NULL,
    system_time_utc   TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

------------------------------------------------------------
-- Index: find devices updated in the last N minutes
------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_telemetry_latest_system_time_utc
    ON app.telemetry_latest (system_time_utc);

------------------------------------------------------------
-- Trigger: update telemetry_latest after insert on telemetry_event
------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_telemetry_event_upsert_latest ON app.telemetry_event;
CREATE TRIGGER trg_telemetry_event_upsert_latest
AFTER INSERT ON app.telemetry_event
FOR EACH ROW
EXECUTE FUNCTION app.fn_upsert_telemetry_latest();

RESET ROLE;
