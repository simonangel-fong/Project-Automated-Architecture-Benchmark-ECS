-- V021__seed_tb_telemetry_event.sql
------------------------------------------------------------
-- Seed sample telemetry_event data for each registered device.
------------------------------------------------------------

SET LOCAL ROLE app_owner;

INSERT INTO app.telemetry_event (device_uuid, x_coord, y_coord, device_time)
VALUES
    -- device-001
    ('e003031d-e441-4ece-ba5b-7d54d5b1da21', 1.2, 3.4, NOW()),
    ('e003031d-e441-4ece-ba5b-7d54d5b1da21', 1.5, 3.8, NOW() + INTERVAL '10 second'),

    -- device-002
    ('d6a07ca5-0ce9-41c3-8dc8-eec41b47b47b', 2.0, 4.1, NOW()),
    ('d6a07ca5-0ce9-41c3-8dc8-eec41b47b47b', 2.3, 4.4, NOW() + INTERVAL '10 second'),

    -- device-003
    ('aa1b41a2-c8f6-44c7-9644-4e9b719a66e9', 3.1, 5.0, NOW()),
    ('aa1b41a2-c8f6-44c7-9644-4e9b719a66e9', 3.4, 5.3, NOW() + INTERVAL '10 second'),

    -- device-004
    ('637c72d6-8ed3-4bf1-b23a-8ec84204846f', 4.2, 6.1, NOW()),
    ('637c72d6-8ed3-4bf1-b23a-8ec84204846f', 4.6, 6.4, NOW() + INTERVAL '10 second'),

    -- device-005
    ('199a53cd-1d9c-4b43-8e46-5f1e1e10c4f8', 5.0, 2.5, NOW()),
    ('199a53cd-1d9c-4b43-8e46-5f1e1e10c4f8', 5.4, 2.8, NOW() + INTERVAL '10 second'),

    -- device-006
    ('1992af01-6789-4072-a516-eb251fa66bd3', 6.3, 1.5, NOW()),
    ('1992af01-6789-4072-a516-eb251fa66bd3', 6.6, 1.9, NOW() + INTERVAL '10 second'),

    -- device-007
    ('9ee2c87c-d990-44cc-a51f-fe3414daddd6', 7.1, 8.2, NOW()),
    ('9ee2c87c-d990-44cc-a51f-fe3414daddd6', 7.5, 8.4, NOW() + INTERVAL '10 second'),

    -- device-008
    ('4b02cbb7-53ea-4dff-8d5d-b93db0dcb5c1', 8.0, 7.0, NOW()),
    ('4b02cbb7-53ea-4dff-8d5d-b93db0dcb5c1', 8.3, 7.3, NOW() + INTERVAL '10 second'),

    -- device-009
    ('8ce6142d-28d5-4dcf-82a9-ef9326c93f03', 9.0, 0.5, NOW()),
    ('8ce6142d-28d5-4dcf-82a9-ef9326c93f03', 9.4, 0.9, NOW() + INTERVAL '10 second'),

    -- device-010
    ('03618450-a5c7-4bb4-a437-21e978a41c5e', 0.8, 9.1, NOW()),
    ('03618450-a5c7-4bb4-a437-21e978a41c5e', 1.1, 9.4, NOW() + INTERVAL '10 second');

RESET ROLE;

------------------------------------------------------------
-- Confirm
------------------------------------------------------------
-- SELECT *
-- FROM app.telemetry_event;

-- SELECT *
-- FROM app.telemetry_latest;