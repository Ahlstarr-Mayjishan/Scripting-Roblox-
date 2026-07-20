CREATE TABLE IF NOT EXISTS auth_requests (
    request_hash TEXT PRIMARY KEY,
    state_hash TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'approved', 'denied')),
    discord_user_id TEXT,
    display_name TEXT,
    role_ids_json TEXT,
    denied_reason TEXT,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    completed_at INTEGER
);

CREATE INDEX IF NOT EXISTS auth_requests_expiry
    ON auth_requests (expires_at);

CREATE TABLE IF NOT EXISTS sessions (
    token_hash TEXT PRIMARY KEY,
    discord_user_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    role_ids_json TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    last_seen_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS sessions_expiry
    ON sessions (expires_at);
