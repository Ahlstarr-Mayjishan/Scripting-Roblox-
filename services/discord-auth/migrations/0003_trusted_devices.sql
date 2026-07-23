ALTER TABLE auth_requests ADD COLUMN resume_code_hash TEXT;
ALTER TABLE auth_requests ADD COLUMN resume_client_hash TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS auth_requests_resume_code
    ON auth_requests (resume_code_hash)
    WHERE resume_code_hash IS NOT NULL;

CREATE TABLE IF NOT EXISTS trusted_devices (
    discord_user_id TEXT NOT NULL,
    client_hash TEXT NOT NULL,
    device_label TEXT NOT NULL,
    first_seen_at INTEGER NOT NULL,
    last_seen_at INTEGER NOT NULL,
    last_ip_hash TEXT,
    last_country TEXT,
    last_asn TEXT,
    revoked_at INTEGER,
    PRIMARY KEY (discord_user_id, client_hash)
);

CREATE INDEX IF NOT EXISTS trusted_devices_active_user
    ON trusted_devices (discord_user_id, revoked_at, last_seen_at);

CREATE TABLE IF NOT EXISTS device_security (
    discord_user_id TEXT PRIMARY KEY,
    last_transfer_at INTEGER NOT NULL
);
