-- V020__seed_tb_device_registry.sql
------------------------------------------------------------
-- Seed sample data into app.device_registry for development and testing.
------------------------------------------------------------

SET LOCAL ROLE app_owner;

INSERT INTO app.device_registry (alias, device_uuid, api_key_hash)
VALUES
    ('device-001', 'e003031d-e441-4ece-ba5b-7d54d5b1da21', '99f93d33035dd7bef57594c41d0f5efc7a5ffefbd00cc24856437596341d444d'),
    ('device-002', 'd6a07ca5-0ce9-41c3-8dc8-eec41b47b47b', '66ae0f8285772deedc9fb1a27b23ce2ce226f47a1750ac030c84345d3c35c7b2'),
    ('device-003', 'aa1b41a2-c8f6-44c7-9644-4e9b719a66e9', 'Cdf24c6b257e44412c03548a3be1c094a302f2649a09a07e2af649ca373d44d2'),
    ('device-004', '637c72d6-8ed3-4bf1-b23a-8ec84204846f', 'A74454003f9d31773ecbb1cab7a20b9333614af8258378161fb315ef4e71b637'),
    ('device-005', '199a53cd-1d9c-4b43-8e46-5f1e1e10c4f8', '4c2f9b2447bb21ed837f14aa8350154d3b1fc1ae499867d44deecb76c495ab4f'),
    ('device-006', '1992af01-6789-4072-a516-eb251fa66bd3', '1a3f015b6b195355562b401ad8b2f73a44ea8aad15fb4582f266bc01e4fd53ea'),
    ('device-007', '9ee2c87c-d990-44cc-a51f-fe3414daddd6', '45166388b314c25ab1d11d90e5facb7ca66b51d49d5f9e786b15e45c784f5360'),
    ('device-008', '4b02cbb7-53ea-4dff-8d5d-b93db0dcb5c1', '3c5a6b18ce89bd774d0d721fbfd4f72641a8606f27eae6cc0d6167dad33f8146'),
    ('device-009', '8ce6142d-28d5-4dcf-82a9-ef9326c93f03', '87b59d61f79ff74e3e137079e65d856d476aaabfbc0775da633d579db44d6781'),
    ('device-010', '03618450-a5c7-4bb4-a437-21e978a41c5e', '8c6a752eb54049a2605ae9d70dfc15961ee30e7fdff47a9b8d78906283554118')
ON CONFLICT (device_uuid) DO NOTHING;

RESET ROLE;

------------------------------------------------------------
-- Confirm
------------------------------------------------------------
-- SELECT *
-- FROM app.device_registry;